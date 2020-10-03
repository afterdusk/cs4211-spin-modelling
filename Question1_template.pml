#define true 1
#define false 0

bool busy [2];

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
        od;
        out!stop;
        busy[id]=false
     ::atomic{!busy[id]->busy[id]=true};
          out!start;
          in?ack;
          do
              ::out!data->in?data
              ::out!stop->break
          od;
          in?stop;
          busy[id]=false
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


#define p1 []((busy[0] == true) -> <>(busy[0] == false))
#define p2 []((busy[1] == true) -> <>(busy[1] == false))
ltl q {p1 && p2}
