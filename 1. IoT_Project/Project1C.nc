
#include "Timer.h"
#include "Project1.h"
#include <unistd.h>
#include <arpa/inet.h>
#include <sys/socket.h>

#define SERVER_IP "127.0.0.1"
#define SERVER_PORT 1234


module Project1C @safe() {
  uses {
    /****** INTERFACES *****/
	interface Boot;

    //interfaces for communication
    interface Receive;
    interface AMSend;
    
	//interface for timers
	interface Timer<TMilli> as Timer0;
	interface Timer<TMilli> as Timer1;
	
    //other interfaces, if needed
    interface SplitControl as AMControl;
    interface Packet;
    interface Random;
  }
}
implementation {

  //variables to store the message to send
  message_t packet;

  //array for storing the nodes subscribed to each topic
  uint16_t subToTopic0[8]={0,0,0,0,0,0,0,0};
  uint16_t subToTopic1[8]={0,0,0,0,0,0,0,0};
  uint16_t subToTopic2[8]={0,0,0,0,0,0,0,0};
  int i=0;
  int k=0;
  int numSub = 0;

  //array of connections, if node i-th is connected, then connections[i-1]=1, else connections[i-1]=0; nodes go from ID=1 to ID=8 (ID=0 is the coordinator)
  uint16_t connections [8] = {0,0,0,0,0,0,0,0};

  //function for sending messages
  bool Mysend(uint16_t address, message_t* p);
 
  
  //------------------------------------------------------------------------------------------------------------------
  
   bool Mysend(uint16_t address, message_t* p){
	//variable for parsing the uint16_t to am_addr_t accepted by AMSend.send
	am_addr_t a = address;
	
	//We display on the dbg when the call of the send returns success as the result
	if (call AMSend.send(a, p, sizeof(msg_t)) == SUCCESS) {
		dbg("radio_send", "Sending packet");	
		dbg_clear("radio_send", " at time %s \n", sim_time_string());
		return TRUE;
	}
	return FALSE;
  }
  
  event void Boot.booted() {
    dbg("boot","Application booted.\n");
    /* Fill it ... */
    call AMControl.start();
  }

  event void AMControl.startDone(error_t err) {
	/* Fill it ... */
	if (err == SUCCESS) {
      dbg("radio","Start done on node %d!\n", TOS_NODE_ID);
	  //when the 5000 ms finishes the Timer will be fired only one time
	  

	  if(TOS_NODE_ID == 0){
	  	call Timer0.startOneShot(0);
	  }else if(TOS_NODE_ID == 1){
		call Timer0.startOneShot(1000);
	  }else if(TOS_NODE_ID == 2){
	  	call Timer0.startOneShot(2000);
	  }else if(TOS_NODE_ID == 3){
	  	call Timer0.startOneShot(3000);
	  }else if(TOS_NODE_ID == 4){
	  	call Timer0.startOneShot(4000);
	  }else if(TOS_NODE_ID == 5){
	  	call Timer0.startOneShot(5000);
	  }else if(TOS_NODE_ID == 6){
	  	call Timer0.startOneShot(6000);
	  }else if(TOS_NODE_ID == 7){
	  	call Timer0.startOneShot(7000);
	  }else if(TOS_NODE_ID == 8){
	  	call Timer0.startOneShot(8000);
	  }      
    }
    else {
      dbgerror("radio", "Radio failed to start, retrying...\n");
      call AMControl.start();
    }
  }

  event void AMControl.stopDone(error_t err) {
    /* Fill it ... */
    dbg("boot", "Radio stopped!\n");
  }
  
  event void Timer0.fired() {
  
	msg_t* rcm;
	msg_t* rcm2;
	
	//each node sends a CONNECT message to PAN COORD 
	if(TOS_NODE_ID != 0){
	
		dbg("timer", "TIMER FIRED node: %d\n", TOS_NODE_ID);
	
		rcm2 = (msg_t*)call Packet.getPayload(&packet, sizeof(msg_t));
		if (rcm2 == NULL) {
			return;
	  	}

		//set the parametes for the CONNECT message
		rcm2->type = 0;
		rcm2->nodeID = TOS_NODE_ID;	
		
		dbg("timer", "Node: %d tries to send CONNECT message\n", TOS_NODE_ID);
		
		Mysend(0, &packet);		
	}
	else if(TOS_NODE_ID == 0){
		dbg("timer", "PANCOORD IS ACTIVE\n");
	}	
  }
  
  //the first phase is ended (CONNECT + SUBSCRIVE), now the nodes can PUBLISH
  event void Timer1.fired(){
  
  		msg_t* rcm2;
  
  		rcm2 = (msg_t*)call Packet.getPayload(&packet, sizeof(msg_t));
		if (rcm2 == NULL) {
			return;
	  	}
	  	
	  	rcm2->type = 4;
	  	rcm2->nodeID = TOS_NODE_ID;
	  	rcm2->topic = call Random.rand16()%3;
	  	rcm2->value = call Random.rand16()%100;
	  	
	  	dbg("timer", "PUBLISH MESSAGE node:%d topic: %d value: %d------------------------------\n", TOS_NODE_ID, rcm2->topic, rcm2->value);
	  	
	  	Mysend(0, &packet);  
  }

  event message_t* Receive.receive(message_t* bufPtr, void* payload, uint8_t len) {

	msg_t* rcm;
	msg_t* rcm2;
	bool endSub = TRUE;
	int sockfd;
	struct sockaddr_in servaddr;

	//Look at the message received and check the type (0,1,2,3,4)
	if (len != sizeof(msg_t)) {
		return bufPtr;}
    else {	
		rcm = (msg_t*)payload;
		
		/*If I'm the PAN coordinator, I have to check if I've received a CONNECT (type 0) message or a SUBSCRIBE (type 2) or a PUBLISH (type 4) */
	    if(TOS_NODE_ID == 0){
	    
	    	if(rcm->type == 0){
				dbg("timer", "TYPE 0: CONNECT message received------------------------------------------------------\n");
				
				connections[(rcm->nodeID)-1]=1;
				
				rcm2 = (msg_t*)call Packet.getPayload(&packet, sizeof(msg_t));
				if (rcm2 == NULL) {
					return bufPtr;
			  	}
				rcm2->type = 1;
		
				dbg("timer", "PAN COORD tries to send CONNACK message\n");
		
				Mysend(rcm->nodeID, &packet);
		  	
			}
			else if(connections[(rcm->nodeID)-1] == 1 && rcm->type == 2){ //The sender is connected and it's a subscribe message
				dbg("timer", "TYPE 2: SUBSCRIBE message received from node %d topic %d-------------------------------\n", rcm->nodeID, rcm->topic);
				rcm2 = (msg_t*)call Packet.getPayload(&packet, sizeof(msg_t));
				if (rcm2 == NULL) {
					return bufPtr;
			  	}
				rcm2->type = 3;
		
				//update arrays of subscriptions
				if(rcm->topic == 0){
					subToTopic0[(rcm->nodeID)-1] = 1;
				}else if(rcm->topic == 1){
					subToTopic1[(rcm->nodeID)-1] = 1;
				}else if(rcm->topic == 2){
					subToTopic2[(rcm->nodeID)-1] = 1;
				}
				
		
				dbg("timer", "PAN COORD tries to send SUBACK message\n");
		
				Mysend(rcm->nodeID, &packet);
				
				//check if the subscription phase is ended
				for(i=0; i<8; i++){
					if((subToTopic0[i] || subToTopic1[i] || subToTopic2[i]) && (subToTopic0[0] && subToTopic1[0] && subToTopic1[2] && subToTopic2[2] && subToTopic0[5] && subToTopic1[5] && subToTopic2[5])){
						endSub = TRUE;
					}else{
						endSub = FALSE;
						break;
					}
						
				}
				//if it is ended, the PAN COORD sends a message for starting the second phase (PUBLISH)
				if(endSub){

				  	rcm2->type = 5;
					
					Mysend(AM_BROADCAST_ADDR, &packet);
				}
				
		  	
			}
			else if(connections[(rcm->nodeID)-1] == 1 && rcm->type == 4){ //The sender is connected and it's a publish message
				dbg("timer", "TYPE 4: PUBLISH message received------------------------------------------------------\n");
				
				rcm2 = (msg_t*)call Packet.getPayload(&packet, sizeof(msg_t));
				if (rcm2 == NULL) {
					return bufPtr;
			  	}

				//check the topic
				if(rcm->topic == 0){
					//forwarding the message to all the node subscribed
					for(i=0; i<8; i++){
						if(subToTopic0[i] == 1){
							//forward
							rcm2->type = 4;
							rcm2->value = rcm->value;
							rcm2->topic = 0;
							
							Mysend(i+1, &packet);
							
							dbg("timer", "FORWARDING on topic %d to subscriber %d--------------------------------------------\n", rcm->topic, i+1);
						}
					}

				}else if(rcm->topic == 1){
					//forwarding the message to all the node subscribed
					for(i=0; i<8; i++){
						if(subToTopic1[i] == 1){
							//forward
							rcm2->type = 4;
							rcm2->value = rcm->value;
							rcm2->topic = 1;
							
							Mysend(i+1, &packet);
							
							dbg("timer", "FORWARDING on topic %d to subscriber %d--------------------------------------------\n", rcm->topic, i+1);
						}
					}

				}else if(rcm->topic == 2){
					//forwarding the message to all the node subscribed
					for(i=0; i<8; i++){
						if(subToTopic2[i] == 1){
							//forward
							rcm2->type = 4;
							rcm2->value = rcm->value;
							rcm2->topic = 2;
							
							Mysend(i+1, &packet);
							
							dbg("timer", "FORWARDING on topic %d to subscriber %d--------------------------------------------\n", rcm->topic, i+1);
						}
					}

				}
				
				
				/*
				**Code fo sending to NodeRed
				*/
				dbg("radio_rec", "Sending PUB messages to Node-RED\n");
				// Send the message to Node-RED TCP node
				// Create socket
				sockfd = socket(AF_INET, SOCK_STREAM, 0);
				if(sockfd == -1)
				{
					dbg("error", "Socket creation failed!\n");
					return bufPtr;
				}
				// Set server address
				servaddr.sin_family = AF_INET;
				servaddr.sin_addr.s_addr = inet_addr(SERVER_IP);
				servaddr.sin_port = htons(SERVER_PORT);
				// Connect to the server
				if(connect(sockfd, (struct sockaddr*)&servaddr, sizeof(servaddr)) != 0)
				{
					dbg("error", "Connection with the server failed!\n");
					close(sockfd);
					return bufPtr;
				}
				// Send the message
				if(send(sockfd, rcm, sizeof(msg_t), 0) == -1)
				{
					dbg("error", "Failed to send message!\n");
					return bufPtr;
				}
				
				close(sockfd);
				sleep(10); // Emulate the periodic sending of messages
				
				return bufPtr;
		  	
			}
	    
	    }else{ /*If I'm a node, I have to check if I've received a CONNACK (type 1) message or a SUBACK (type 3)*/
	    	if(rcm->type == 1){
				dbg("timer", "TYPE 1: CONNACK message received------------------------------------------------------\n");
				
				rcm2 = (msg_t*)call Packet.getPayload(&packet, sizeof(msg_t));
				if (rcm2 == NULL) {
					return bufPtr;
			  	}

				//the nodes subscribe to the topics
				if(TOS_NODE_ID == 1){
					rcm2->nodeID = TOS_NODE_ID;
					rcm2->topic = 0;
					rcm2->type = 2;
					Mysend(0, &packet);
					numSub = 1;
					
				}else if (TOS_NODE_ID == 3){
					rcm2->nodeID = TOS_NODE_ID;
					rcm2->topic = 1;
					rcm2->type = 2;
					Mysend(0, &packet);
					numSub = 1;
					
				}else if (TOS_NODE_ID == 6){
					rcm2->nodeID = TOS_NODE_ID;
					rcm2->topic = 0;
					rcm2->type = 2;
					Mysend(0, &packet);
					numSub = 1;
					
				}else{
					rcm2->nodeID = TOS_NODE_ID;
					rcm2->topic = call Random.rand16()%3;
					rcm2->type = 2;			
					Mysend(0, &packet);
				}

			}
			else if(rcm->type == 3){
				dbg("timer", "TYPE 3: SUBACK message received------------------------------------------------------\n");
		  		
		  		rcm2 = (msg_t*)call Packet.getPayload(&packet, sizeof(msg_t));
				if (rcm2 == NULL) {
					return bufPtr;
			  	}
		  		
		  		if (TOS_NODE_ID == 1 && numSub < 2){
		  			rcm2->nodeID = TOS_NODE_ID;
					rcm2->topic = 1;
					rcm2->type = 2;
					Mysend(0, &packet);
					numSub = 2;
					
		  		}else if (TOS_NODE_ID == 3 && numSub < 2){					
					rcm2->nodeID = TOS_NODE_ID;
					rcm2->topic = 2;
					rcm2->type = 2;
					Mysend(0, &packet);
					numSub = 2;
		  		}
		  		
		  		else if (TOS_NODE_ID == 6 && numSub < 3){
		  			rcm2->nodeID = TOS_NODE_ID;
					rcm2->topic = numSub;
					rcm2->type = 2;
					Mysend(0, &packet);
					numSub ++;
		  		}
		  		
		  		
			}
			else if(rcm->type == 5){
				
				
			    if(TOS_NODE_ID == 1){
				  call Timer1.startPeriodicAt(1000, 9000);
			    }else if(TOS_NODE_ID == 2){
			  	  call Timer1.startPeriodicAt(2000, 9000);
			    }else if(TOS_NODE_ID == 3){
			  	  call Timer1.startPeriodicAt(3000, 9000);
			    }else if(TOS_NODE_ID == 4){
			  	  call Timer1.startPeriodicAt(4000, 9000);
			    }else if(TOS_NODE_ID == 5){
			  	  call Timer1.startPeriodicAt(5000, 9000);
			    }else if(TOS_NODE_ID == 6){
			  	  call Timer1.startPeriodicAt(6000, 9000);
			    }else if(TOS_NODE_ID == 7){
			  	  call Timer1.startPeriodicAt(7000, 9000);
			    }else if(TOS_NODE_ID == 8){
			  	  call Timer1.startPeriodicAt(8000, 9000);
			    }	  
			}
	    }
  	 }
  	 
  	 return bufPtr;
  }//END receive
	
  event void AMSend.sendDone(message_t* bufPtr, error_t error) {
	/* This event is triggered when a message is sent 
	*  Check if the packet is sent 
	*/ 
	if (&packet == bufPtr) {
      dbg("radio_send", "Packet sent...");
      dbg_clear("radio_send", " at time %s \n", sim_time_string());
    }
 }
}
