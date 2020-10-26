// composed represents a struct containing a red, a green and a blue message
mtype = {red, green, blue, composed};
chan in[3] = [0] of {mtype};
chan out = [1] of {mtype};

proctype incoming(mtype type; chan stream) {
  do
    ::stream!type;
  od;
}

proctype outgoing(chan stream) {
  do
    ::stream?composed;
  od;
}

proctype node(chan redStream, greenStream, blueStream, outStream) {
  chan buffer = [6] of {mtype};
  do
    ::len(buffer) < 6 ->
      if
        ::redStream?red -> buffer!red;
        ::greenStream?green -> buffer!green;
        ::blueStream?blue -> buffer!blue;
      fi;
    // [ ] syntax reads from channel but does not consume
    // ?? syntax reads from anywhere in the channel, not just the front
    ::buffer??[red] && buffer??[green] && buffer??[blue]->
      buffer??red;
      buffer??green;
      buffer??blue;
      outStream!composed;
  od;
}

init{
    atomic{
      run incoming(red, in[0]);
      run incoming(green, in[1]);
      run incoming(blue, in[2]);
      run outgoing(out);
      run node(in[0], in[1], in[2], out);
    }
}

ltl q {[](<>(len(out) > 0))}