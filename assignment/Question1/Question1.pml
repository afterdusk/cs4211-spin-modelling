#define true 1
#define false 0

bool busy [2];
int turn[2];

mtype = {start,stop,data,ack};

chan up[2] = [1] of {mtype};
chan down[2] = [1] of {mtype};

proctype station(byte id; chan in, out){
  do
    ::in?start->
      atomic{!busy[id]->busy[id]=true};
      out!ack;
      do
        ::in?data->out!data
        ::in?stop->break
      od
      out!stop;
      turn[id] = 1 - turn[id];
      busy[id]=false;

    ::atomic{!busy[id] && turn[id] == id -> busy[id]=true};
      out!start;
      in?ack;
      int count = 3;
      do
        ::count > 0->
          out!data; 
          in?data;
          count--;
        ::out!stop->break
      od;
      in?stop;
      turn[id] = 1 - turn[id];
      busy[id]=false;
  od
}

init{
  atomic{
      run station(0,up[1],down[1]);
      run station(1,up[0],down[0]);
      run station(0,down[0],up[0]);
      run station(1,down[1],up[1]);
  }
}

#define p1 []((down[1]?<start>) -> <>(up[1]?<stop>))
#define p2 []((down[0]?<start>) -> <>(up[0]?<stop>))
#define p3 []((up[0]?<start>) -> <>(down[0]?<stop>))
#define p4 []((up[1]?<start>) -> <>(down[1]?<stop>))
ltl q {p1 && p2 && p3 && p4}
