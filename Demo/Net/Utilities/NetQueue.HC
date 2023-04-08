/*  Shrine mentions possibly using two FIFOs
    (in our case, Ques) for pending and
    empty frames. If logical to implement,
    perhaps Zeal NetQue code should
    do something similar to that idea.

    Each Ethernet Frame will be represented
    as an entry in a CQue. */

class CNetQueEntry:CQue
{
  I64 packet_length;
  U8    frame[ETHERNET_FRAME_SIZE];
};


/*  global variable, holds pointer of Ethernet Que.
    This acts as the Head of the Que, Entries act
    as the Tail of the Que.
    Upon QueInit, ->next and ->last are set to
    itself, the Head. */

CQue *net_queue; // no QueRem the Head! only Entries!

U0 NetQueInit()
{
  net_queue = CAlloc(sizeof(CQue));
  QueInit(net_queue);
}

CNetQueEntry *NetQuePull()
{
  /*    Returns a pointer to a CNetQueEntry,
  or NULL pointer if Net Que is empty. */
  CNetQueEntry *entry;
  if (net_queue->next != net_queue)
  {
    entry = net_queue->next;
    NetLog("NETQUEUE PULL: Removing entry from queue.");
    QueRem(entry);
  }
  else // Que is empty if head->next is head itself.
  {
    entry = NULL;
  }
  return entry;
}

U0 NetQuePush(U8 *data, I64 length)
{
  /*    Pushes a copy of the packet data and length
  into the Net Que. The NetQueEntry is inserted
  after the last entry of net_queue to keep new
  items in the back of the Que, old in front. */
  CNetQueEntry *entry = CAlloc(sizeof(CNetQueEntry));
  entry->packet_length = length;
  MemCpy(entry->frame, data, length);
  QueIns(entry, net_queue->last);
  // Wake Net Handler
  if (netfifo_handler_task)
  {
    NetLog("NETQUEUE PUSH COPY: Waking NetHandler.");
    LBtr(&netfifo_handler_task->task_flags, TASKf_IDLE);
    Yield;
  }
  else
  {
    NetLog("NETQUEUE PUSH COPY: Error, no NetHandler task!");
  }
}


NetQueInit;
