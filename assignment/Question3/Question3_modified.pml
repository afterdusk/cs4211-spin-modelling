#define true 1
#define false 0

// component states
mtype:managerStates = {idle, preini, ini, postini, preup, up, postup, postrev};
mtype:clientStates = {disconnected, preClientIni, clientIni, postClientIni, preClientUp, clientUp, postClientUp, postClientRev, idleClient};
mtype:controlStates = {off, on};

// types of messages
mtype:clientMsg = {getWeather, useWeather, useOldWeather, refuse, ack};
mtype:managerMsg = {connect, weather, use};
mtype:managerControlMsg = {update}

// component channels
// model augmentation: increase size of channel to let connect requests sit
//                     add separate channel for WCP -> cm
chan managerPort = [5] of {mtype:managerMsg, int, int};
chan managerControlPort = [0] of {mtype:managerControlMsg};
chan clientPort[3] = [0] of {mtype:clientMsg};

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
      port?ack;
    // model augmentation: dropped refuse message
    // ::port?refuse;
  od;
}

proctype clientManager() {
  int requestor = -1;
  int id;
  int i;
  int numClients = 0;
  int clientIds[3];
  do
    // model augmentation: requests only entertained when client manager is idle
    // ::managerPort?connect, _, requestor->
    //   if
    //     ::managerState == idle ->
    //       managerState = preini;
    //       clientState[requestor] = preClientIni;
    //       controlState = off;
    //     ::else ->
    //       clientPort[requestor]!refuse;
    //   fi;
    // ::managerPort?update, _, _ ->
    //   if
    //     ::managerState == idle ->
    //       for (i : 0 .. (numClients-1)) {
    //         id = clientIds[i];
    //         clientState[id] = preClientUp;
    //       }
    //       managerState = preup;
    //       controlState = off;
    //     ::else
    //   fi;
    ::managerState == idle ->
      if
        ::managerPort??connect, _, requestor->
          managerState = preini;
          clientState[requestor] = preClientIni;
          controlState = off;
          // model augmentation: ack the connect request
          clientPort[requestor]!ack;
        ::managerControlPort?update, _, _ ->
          for (i : 0 .. (numClients-1)) {
            id = clientIds[i];
            clientState[id] = preClientUp;
          }
          managerState = preup;
          controlState = off;
      fi;
    ::managerState == preini ->
      clientPort[requestor]!getWeather;
      managerState = ini;
      clientState[requestor] = clientIni;
    ::managerState == ini ->
      if
        ::managerPort??weather, true, eval(requestor) ->
          clientPort[requestor]!useWeather;
          clientState[requestor] = postClientIni;
          managerState = postini;
        ::managerPort??weather, false, eval(requestor) ->
          clientState[requestor] = disconnected;
          managerState = idle;
          requestor = -1;
          // model augmentation: WCP enabled on failure to get weather
          controlState = on;
      fi;
    ::managerState == postini ->
      if
        ::managerPort??use, true, eval(requestor) ->
          clientState[requestor] = idleClient;
          managerState = idle;
          controlState = on;
          // add requestor id to list of connected clients
          clientIds[numClients] = requestor;
          numClients++;
          // reset requestor variable
          requestor = -1;

        ::managerPort??use, false, eval(requestor) ->
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
          ::managerPort??weather, true, eval(id);
          ::managerPort??weather, false, eval(id) ->
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
          ::managerPort??use, true, eval(id);
          ::managerPort??use, false, eval(id) ->
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
          ::managerPort??use, true, eval(id);
          ::managerPort??use, false, eval(id) ->
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
      managerControlPort!update;
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
