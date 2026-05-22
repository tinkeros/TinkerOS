U0 StructInfo(U8 *d,U8 *class_name=lastclass, I64 size=firstsize)
{//lastclass is the prev fun arg's class as a string.
  "%X is a ptr to a %d byte sized \"%s\" object.\n",d,size,class_name;
}

class Student
{
  Student *next;
  I64 age;
  U8 name[32];
} a;

class School
{
  U8 name[32];
  Student *students;
} s;

StructInfo(Fs);
StructInfo(&a);
StructInfo(&s);

