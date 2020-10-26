#define true 1
#define false 0

// component states
mtype:managerStates = {idle, preini, ini, postini, preup, up, postup, postrev};
mtype:clientStates = {disconnected, preClientIni, clientIni, postClientIni, preClientUp, clientUp, postClientUp, postClientRev, idleClient};
mtype:controlStates = {off, on};

// types of messages
mtype:clientMsg = {getWeather, useWeather, useOldWeather, refuse};
mtype:managerMsg = {connect, weather, use, update};

// component channels
chan managerPort = [1] of {mtype:managerMsg, int, int};
chan clientPort[3] = [1] of {mtype:clientMsg};

// global declaration of state
mtype:managerStates managerState;
mtype:controlStates controlState;
mtype:clientStates clientState[3];

proctype client(int id; chan port) {
  do
    ::port?getWeather ->
      if
        ::managerPort!weather(true, id);
        ::managerPort!weather(false, id);
      fi;
    ::port?useWeather ->
      if
        ::managerPort!use(true, id);
        ::managerPort!use(false, id);
      fi;
    ::port?useOldWeather ->
      if
        ::managerPort!use(true, id);
        ::managerPort!use(false, id);
      fi;

    ::clientState[id] == disconnected ->
      managerPort!connect(0, id);
    ::port?refuse;
  od;
}

proctype clientManager() {
  int requestor = -1;
  int id;
  int i;
  int numClients = 0;
  int clientIds[3];
  do
    ::managerPort?connect, _, requestor->
      if
        ::managerState == idle ->
          managerState = preini;
          clientState[requestor] = preClientIni;
          controlState = off;
        ::else ->
          clientPort[requestor]!refuse;
      fi;
    ::managerPort?update, _, _ ->
      if
        ::managerState == idle ->
          for (i : 0 .. (numClients-1)) {
            id = clientIds[i];
            clientState[id] = preClientUp;
          }
          managerState = preup;
          controlState = off;
        ::else
      fi;

    ::managerState == preini ->
      clientPort[requestor]!getWeather;
      managerState = ini;
      clientState[requestor] = clientIni;
    ::managerState == ini ->
      if
        ::managerPort?weather, true, eval(requestor) ->
          clientPort[requestor]!useWeather;
          clientState[requestor] = postClientIni;
          managerState = postini;
        ::managerPort?weather, false, eval(requestor) ->
          clientState[requestor] = disconnected;
          managerState = idle;
          requestor = -1;
          // deadlock here, WCP not enabled
      fi;
    ::managerState == postini ->
      if
        ::managerPort?use, true, eval(requestor) ->
          clientState[requestor] = idleClient;
          managerState = idle;
          controlState = on;
          // add requestor id to list of connected clients
          clientIds[numClients] = requestor;
          numClients = numClients + 1;
          // reset requestor variable
          requestor = -1;

        ::managerPort?use, false, eval(requestor) ->
          clientState[requestor] = disconnected;
          controlState = on;
          managerState = idle;
          requestor = -1;
      fi;
    ::managerState == preup ->
      for (i : 0 .. (numClients-1)) {
        id = clientIds[i];
        clientPort[id]!getWeather;
      }
      for (i : 0 .. (numClients-1)) {
        id = clientIds[i];
        clientState[id] = clientUp;
      }
      managerState = up;
    ::managerState == up ->
      int isSuccess = 1;
      for (i : 0 .. (numClients-1)) {
        id = clientIds[i];
        if
          ::managerPort?weather, true, eval(id);
          ::managerPort?weather, false, eval(id) ->
            isSuccess = 0;
        fi;
      }
      if
        ::isSuccess == 1 ->
          for (i : 0 .. (numClients-1)) {
            id = clientIds[i];
            clientPort[id]!useWeather;
            clientState[id] = postClientUp;
          }
          managerState = postup;
        ::isSuccess == 0 ->
          for (i : 0 .. (numClients-1)) {
            id = clientIds[i];
            clientPort[id]!useOldWeather;
            clientState[id] = postClientRev;
          }
          managerState = postrev;
      fi;
    ::managerState == postup ->
      isSuccess = 1;
      for (i : 0 .. (numClients-1)) {
        id = clientIds[i];
        if
          ::managerPort?use, true, eval(id);
          ::managerPort?use, false, eval(id) ->
            isSuccess = 0;
        fi;
      }
      if
        ::isSuccess == 1 ->
          for (i : 0 .. (numClients-1)) {
            id = clientIds[i];
            clientState[id] = idleClient;
          }
        ::isSuccess == 0 ->
          for (i : 0 .. (numClients-1)) {
            id = clientIds[i];
            clientState[id] = disconnected;
          }
          numClients = 0;
      fi;
      controlState = on;
      managerState = idle;
    ::managerState == postrev ->
      isSuccess = 1;
      for (id : 0 .. (numClients-1)) {
        if
          ::managerPort?use, 1, eval(id);
          ::managerPort?use, 0, eval(id) ->
            isSuccess = 0;
        fi;
      }
      if
        ::isSuccess == 1 ->
          for (i : 0 .. (numClients-1)) {
            id = clientIds[i];
            clientState[id] = idleClient;
          }
        ::isSuccess == 0 ->
          for (i : 0 .. (numClients-1)) {
            id = clientIds[i];
            clientState[id] = disconnected;
          }
          numClients = 0;
      fi;
      controlState = on;
      managerState = idle;
  od;

}

proctype controlPanel() {
  do
    ::controlState == on ->
      managerPort!update(0, 0);
  od;
}

init{
    atomic{
      clientState[0] = disconnected;
      clientState[1] = disconnected;
      clientState[2] = disconnected;
      managerState = idle;
      controlState = on;
      run client(0, clientPort[0]);
      run client(1, clientPort[1]);
      run client(2, clientPort[2]);
      run clientManager();
      run controlPanel();
    }
}

ltl q {[](controlState == off -> <>(controlState == on))}
