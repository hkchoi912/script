all:
	g++ -std=c++11 -O2 main.cc -DTIME_FACTOR=1 -o replayer -lrt -I /usr/bin/include -laio
	# g++ -std=c++11 -O2 main.cc -DTIME_FACTOR=2 -o replayer_fast -lrt -I /usr/bin/include -laio

debug:
	g++ -std=c++11 -O0 -g -rdynamic main.cc -DTIME_FACTOR=1 -o replayer -lrt -I /usr/bin/include -laio
	# g++ -std=c++11 -O0 -g -rdynamic main.cc -DTIME_FACTOR=2 -o replayer_fast -lrt -I /usr/bin/include -laio
