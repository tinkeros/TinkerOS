/***************************************************

TCP Bound/Connected Socket Tree Functions

***************************************************/

I64 tcp_bound_tree_lock = 0;

CTCPTreeNode *TCPTreeNodeInit()
{// init new empty tree/node. Init socket queue head links.
  CTCPTreeNode *tree_node = CAlloc(sizeof(CTCPTreeNode), adam_task);
  tree_node->queue = CAlloc(sizeof(CTCPTreeQue), adam_task);
  QueInit(tree_node->queue);
  return tree_node;
}

U0 TCPTreeNodeAdd(CTCPTreeNode *node, CTCPTreeNode *tree)
{// using temp and last allows avoiding recursion and non-growing stack issues.
  BSTAdd(node, tree);
}

CTCPTreeNode *TCPTreeNodeParamAdd(I64 port, CTCPTreeNode *tree)
{// add a node using params, return pointer to the node
  CTCPTreeNode *result = TCPTreeNodeInit;
  result->value = port;
  TCPTreeNodeAdd(result, tree);
  return result;
}

CTCPTreeNode *TCPTreeNodeParamInit(I64 port)
{
  CTCPTreeNode *result = TCPTreeNodeInit;
  result->value = port;
  return result;
}

CTCPTreeNode *TCPTreeNodeFind(I64 port, CTCPTreeNode *tree)
{
  return BSTFind(port, tree);
}

CTCPTreeNode *TCPTreeNodePop(I64 port, CTCPTreeNode *tree)
{// Pops whole sub-tree, original tree loses whole branch.
  return BSTPop(port, tree);
}

CTCPTreeNode *TCPTreeNodeSinglePop(I64 port, CTCPTreeNode *tree)
{// Pop a tree off, then add back in its sub-trees to main tree.
  // Original node sub-tree links are cleared.
  return BSTSinglePop(port, tree);
}

U0 TCPTreeNodeQueAdd(CTCPSock *sock, CTCPTreeNode *node)
{
  CTCPTreeQue *new_ent = CAlloc(sizeof(CTCPTreeQue), adam_task);
  new_ent->sock = sock;
  QueIns(new_ent, node->queue->last);
}

CTCPTreeQue *TCPTreeQueEntInit(CTCPSock *sock)
{//Built before taking tcp_bound_tree_lock, so the guarded section only links.
  CTCPTreeQue *ent = CAlloc(sizeof(CTCPTreeQue), adam_task);
  ent->sock = sock;
  return ent;
}

CTCPTreeQue *TCPTreeNodeQueSockFind(CTCPSock *sock, CTCPTreeNode *node)
{
  CTCPTreeQue *temp_queue;
  temp_queue = node->queue->next;
  while (temp_queue != node->queue)
  {
    if (temp_queue->sock == sock)
      return temp_queue;
    temp_queue = temp_queue->next;
  }
  return NULL;
}

CTCPTreeQue *TCPTreeNodeQueSockSinglePop(CTCPSock *sock, CTCPTreeNode *node)
{// search by socket, pop a single TCPTreeQue off the node, return popped queue.
  CTCPTreeQue *temp_queue = TCPTreeNodeQueSockFind(sock, node);
  if (temp_queue)
  {
    QueRem(temp_queue);
  }
  return temp_queue;
}

CTCPTreeQue *TCPTreeNodeQueIPV4Find(U32 addr, CTCPTreeNode *node, Bool specific=FALSE)
{//No logging: callers hold the bound-tree spinlock with interrupts off.
// address should be pulled from an instance of CIPV4Address (TODO... double check what bit order we're in ?)
  // use TRUE or FALSE in specific arg to dictate how to handle INADDR_ANY.
  CTCPTreeQue       *temp_queue = node->queue->next;
  CSockAddrIPV4    *temp_ip;
  while (temp_queue != node->queue)
  {
    if (temp_queue->sock->dst_addr.family == AF_INET)
    {
      temp_ip = &temp_queue->sock->dst_addr;
      if (temp_ip->addr.addr == addr)
      {
        return temp_queue;
      }
    }
    temp_queue = temp_queue->next;
  }
  if (!specific)
  {
    temp_queue = node->queue->next;
    while (temp_queue != node->queue)
    {
      if (temp_queue->sock->dst_addr.family == AF_INET)
      {
        temp_ip = &temp_queue->sock->dst_addr;
        if (temp_ip->addr.addr == INADDR_ANY)
        {
          return temp_queue;
        }
      }
      temp_queue = temp_queue->next;
    }
  }
  return NULL;
}

