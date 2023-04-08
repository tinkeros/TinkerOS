/***************************************************

UDP Bound Socket Tree Functions

***************************************************/

CUDPTreeNode *UDPTreeNodeInit()
{// init new empty tree/node. Init socket queue head links.
  CUDPTreeNode *tree_node = CAlloc(sizeof(CUDPTreeNode));
  tree_node->queue = CAlloc(sizeof(CUDPTreeQue)); // CQue vs CUDPTreeQue ?...
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

U0 UDPTreeNodeQueAdd(CUDPSocket *socket, CUDPTreeNode *node)
{
  CUDPTreeQue *new_entry = CAlloc(sizeof(CUDPTreeQue));
  new_entry->socket = socket;
  QueIns(new_entry, node->queue->last);
}

CUDPTreeQue *UDPTreeNodeQueSocketFind(CUDPSocket *socket, CUDPTreeNode *node)
{
  CUDPTreeQue *temp_queue;
  temp_queue = node->queue->next;
  while (temp_queue != node->queue)
  {
    if (temp_queue->socket == socket)
      return temp_queue;
    temp_queue = temp_queue->next;
  }
  return NULL;
}

CUDPTreeQue *UDPTreeNodeQueSocketSinglePop(CUDPSocket *socket, CUDPTreeNode *node)
{// search by socket, pop a single UDPTreeQue off the node, return popped queue.
  CUDPTreeQue *temp_queue = UDPTreeNodeQueSocketFind(socket, node);
  if (temp_queue)
  {
    QueRem(temp_queue);
  }
  return temp_queue; // if not found, NULL.
}

CUDPTreeQue *UDPTreeNodeQueIPV4Find(U32 address, CUDPTreeNode *node, Bool specific=FALSE)
{// address should be pulled from an instance of CIPV4Address (TODO... double check what bit order we're in ?)
  // use TRUE or FALSE in specific arg to dictate how to handle INADDR_ANY.
  CUDPTreeQue       *temp_queue = node->queue->next;
  CSocketAddressIPV4    *temp_ip;
  while (temp_queue != node->queue)
  {
    if (temp_queue->socket->receive_address.family == AF_INET)
    {
      temp_ip = &temp_queue->socket->receive_address;
      NetLog("UDPTreeNodeQueIPV4Find: Cmparing:     addr, nodequeue addr: %08X, %08X",
             address, temp_ip->address.address);
      if (temp_ip->address.address == address)
      {
        NetLog("UDPTreeNodeQueIPV4Find: Address match: addr, nodequeue addr: %08X, %08X ",
               address, temp_ip->address.address);
        return temp_queue;
      }
    }
    else
      NetErr("UDPTreeNodeQueIPV4Find: Skipped iteration of a non AF_INET family: %0X",
             temp_queue->socket->receive_address.family);
    temp_queue = temp_queue->next;
  }
  if (!specific)
  {
    temp_queue = node->queue->next;
    NetDbg("UDPTreeNodeQueIPV4Find: Exact match not found, looking for an INADDR_ANY address.");
    while (temp_queue != node->queue)
    {
      if (temp_queue->socket->receive_address.family == AF_INET)
      {
        temp_ip = &temp_queue->socket->receive_address;
        NetLog("UDPTreeNodeQueIPV4Find: Cmparing:     addr, nodequeue addr: %08X, %08X",
               address, temp_ip->address.address);
        if (temp_ip->address.address == INADDR_ANY)
        {
          NetLog("UDPTreeNodeQueIPV4Find: Address match: addr, nodequeue addr: %08X, %08X ",
                 address, temp_ip->address.address);
          return temp_queue;
        }
      }
      else
        NetErr("UDPTreeNodeQueIPV4Find: Skipped iteration of a non AF_INET family: %0X",
               temp_queue->socket->receive_address.family);
      temp_queue = temp_queue->next;
    }
  }
  return NULL;
}
