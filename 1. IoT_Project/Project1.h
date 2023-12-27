

#ifndef PROJECT1_H
#define PROJECT1_H

typedef nx_struct project1_msg {
	/*type=0: CONNECT
	**type=1: CONNACK
	**type=2: SUBSCRIBE
	**type=3: SUBACK
	**type=4: PUBLISH 
	**type=5: endSub
	*/
	nx_uint16_t type;
	
	//In SUBSCRIBE message the node who wants to subscribe to the topic passes its node ID as parameter of the message
	nx_uint16_t nodeID;
	
	/*topic=0: TEMPERATURE
	**topic=1: HUMIDITY
	**topic=2: LUMINOSITY */
	nx_uint16_t topic;
	
	nx_uint16_t value;
	
} msg_t;

enum {
  AM_RADIO_COUNT_MSG = 10,
};

#endif
