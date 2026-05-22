// TempleOS specific memory allocations

// Global scoped array
// - Can be initialized with values
// - Stays in heap, memory not released until task exit
static I64 globalScopeArray[4]={1,2,3,4};

U0 LocalArray()
{
  // Function scoped array
  // Cannot be initialized with values
  // Lives on stack, no free needed
  // Memory released when function returns
  I64 localArray[4];
  no_warn localArray;
}

U0 HeapArray()
{
  // Heap stored arrays
  // Cannot be initialized with values (except 0 with CAlloc).
  // Lives on heap
  // Cleaned up when function returns

  // Uninitialized values
  I64 *heapArray=MAlloc(4*sizeof(I64));
  // Do stuff with it
  Free(heapArray); // Free to release heap memory

  // values initialized to 0
  I64 *heapArray2=CAlloc(4*sizeof(I64));
  // Do stuff with it
  Free(heapArray2); // Free to release heap memory
}

// TinkerOS extensions for heap arrays
class testClass {
  I64 x,y,z;
};

testClass *arr;

U0 ArrayInfo(U8 *ptr, U8 *str=lastclass, I64 s_elem=firstsize)
{
  "This array can hold %d \"%s\""
  " objects each with size of %d bytes.\n",
  MSize(ptr)/s_elem,
  str,
  s_elem;
}

ArrayMAlloc(&arr,10);

"The array can hold %d entries.\n",ArraySize(arr);
"The array can hold %d bytes of space for data.\n",MSize(arr);
"The array (data+overhead) consumes %d bytes of heap space.\n",MSize2(arr);

ArrayReAlloc(&arr,20);

"This array can now hold %d entries\n",ArraySize(arr);

// Array Info (demos lastclass and firstsize)
ArrayInfo(arr);

// Test with global array statically allocated
static testClass arr_static[25];
"The array can hold %d entries.\n",ArraySize(arr_static);

