/*  Shrine mentions possibly using two FIFOs
    (in our case, Ques) for pending and
    empty frames. If logical to implement,
    perhaps Zeal NetQue code should
    do something similar to that idea.

    Each Ethernet Frame will be represented
    as an entry in a CQue. */

class CNetQueEnt:CQue
{
  I64 pkt_len;
  U8    frame[ETH_FRAME_SIZE];
};


/*  global variable, holds pointer of Ethernet Que.
    This acts as the Head of the Que, Entries act
    as the Tail of the Que.
    Upon QueInit, ->next and ->last are set to
    itself, the Head. */

CQue *net_queue;

#define NET_QUEUE_MAX 64
I64 net_queue_depth = 0, net_queue_drops = 0, net_queue_lock = 0;

U0 NetQueInit()
{
  net_queue = CAlloc(sizeof(CQue));
  QueInit(net_queue);
  net_queue_depth = 0;
  net_queue_drops = 0;
  net_queue_lock = 0;
}

CNetQueEnt *NetQuePull()
{
  /*    Returns a pointer to a CNetQueEnt,
  or NULL pointer if Net Que is empty. */
  CNetQueEnt *ent;
  PUSHFD
  CLI
  while (LBts(&net_queue_lock, 0))
    PAUSE
  if (net_queue->next != net_queue)
  {
    ent = net_queue->next;
    QueRem(ent);
    if (net_queue_depth > 0)
      net_queue_depth--;
  }
  else
  {
    ent = NULL;
  }
  LBtr(&net_queue_lock, 0);
  POPFD
  return ent;
}

U0 NetQuePush(U8 *data, I64 len)
{
  CNetQueEnt *ent;
  if (len < 1 || len > ETH_FRAME_SIZE)
    return;
  ent = CAlloc(sizeof(CNetQueEnt), adam_task);
  if (!ent)
    return;
  ent->pkt_len = len;
  MemCpy(ent->frame, data, len);
  PUSHFD
  CLI
  while (LBts(&net_queue_lock, 0))
    PAUSE
  if (net_queue_depth >= NET_QUEUE_MAX)
  {
    net_queue_drops++;
    LBtr(&net_queue_lock, 0);
    POPFD
    Free(ent);
    return;
  }
  QueIns(ent, net_queue->last);
  net_queue_depth++;
  LBtr(&net_queue_lock, 0);
  POPFD
  if (netfifo_handler_task)
    LBtr(&netfifo_handler_task->task_flags, TASKf_IDLE);
}


NetQueInit;
