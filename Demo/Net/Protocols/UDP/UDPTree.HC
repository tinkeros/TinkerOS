/***************************************************

UDP Bound Socket Tree Functions

***************************************************/

I64 udp_bound_tree_lock = 0;

CUDPTreeNode *UDPTreeNodeInit()
{// init new empty tree/node. Init socket queue head links.
  CUDPTreeNode *tree_node = CAlloc(sizeof(CUDPTreeNode), adam_task);
  tree_node->queue = CAlloc(sizeof(CUDPTreeQue), adam_task);
  QueInit(tree_node->queue);
  return tree_node;
}

U0 UDPTreeNodeAdd(CUDPTreeNode *node, CUDPTreeNode *tree)
{// using temp and last allows avoiding recursion and non-growing stack issues.
  BSTAdd(node, tree);
}

CUDPTreeNode *UDPTreeNodeParamAdd(I64 port, CUDPTreeNode *tree)
{// add a node using params, return pointer to the node
  CUDPTreeNode *result = UDPTreeNodeInit;
  result->value = port;
  UDPTreeNodeAdd(result, tree);
  return result;
}

CUDPTreeNode *UDPTreeNodeParamInit(I64 port)
{
  CUDPTreeNode *result = UDPTreeNodeInit;
  result->value = port;
  return result;
}

CUDPTreeNode *UDPTreeNodeFind(I64 port, CUDPTreeNode *tree)
{
  return BSTFind(port, tree);
}

CUDPTreeNode *UDPTreeNodePop(I64 port, CUDPTreeNode *tree)
{// Pops whole sub-tree, original tree loses whole branch.
  return BSTPop(port, tree);
}

CUDPTreeNode *UDPTreeNodeSinglePop(I64 port, CUDPTreeNode *tree)
{// Pop a tree off, then add back in its sub-trees to main tree.
  // Original node sub-tree links are cleared.
  return BSTSinglePop(port, tree);
}

U0 UDPTreeNodeQueAdd(CUDPSock *sock, CUDPTreeNode *node)
{
  CUDPTreeQue *new_ent = CAlloc(sizeof(CUDPTreeQue), adam_task);
  new_ent->sock = sock;
  QueIns(new_ent, node->queue->last);
}

CUDPTreeQue *UDPTreeQueEntInit(CUDPSock *sock)
{//Built before taking udp_bound_tree_lock, so the guarded section only links.
  CUDPTreeQue *ent = CAlloc(sizeof(CUDPTreeQue), adam_task);
  ent->sock = sock;
  return ent;
}

CUDPTreeQue *UDPTreeNodeQueSockFind(CUDPSock *sock, CUDPTreeNode *node)
{
  CUDPTreeQue *temp_queue;
  temp_queue = node->queue->next;
  while (temp_queue != node->queue)
  {
    if (temp_queue->sock == sock)
      return temp_queue;
    temp_queue = temp_queue->next;
  }
  return NULL;
}

CUDPTreeQue *UDPTreeNodeQueSockSinglePop(CUDPSock *sock, CUDPTreeNode *node)
{// search by socket, pop a single UDPTreeQue off the node, return popped queue.
  CUDPTreeQue *temp_queue = UDPTreeNodeQueSockFind(sock, node);
  if (temp_queue)
  {
    QueRem(temp_queue);
  }
  return temp_queue;
}

CUDPTreeQue *UDPTreeNodeQueIPV4Find(U32 addr, CUDPTreeNode *node, Bool specific=FALSE)
{//No logging: callers hold the bound-tree spinlock with interrupts off.
// address should be pulled from an instance of CIPV4Address (TODO... double check what bit order we're in ?)
  // use TRUE or FALSE in specific arg to dictate how to handle INADDR_ANY.
  CUDPTreeQue       *temp_queue = node->queue->next;
  CSockAddrIPV4    *temp_ip;
  while (temp_queue != node->queue)
  {
    if (temp_queue->sock->rx_addr.family == AF_INET)
    {
      temp_ip = &temp_queue->sock->rx_addr;
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
      if (temp_queue->sock->rx_addr.family == AF_INET)
      {
        temp_ip = &temp_queue->sock->rx_addr;
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
