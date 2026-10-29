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

//ClassCpy() uses firstsize the same way, so copying a class onto
//another of the same class needs no sizeof() at the call.
Student b,roster[3],backup[3];
I64 i;

a.next=NULL;
a.age=85;
StrCpy(a.name,"Grace Hopper");

ClassCpy(&b,&a);
"\nClassCpy(&b,&a) copied %d bytes, no sizeof needed.\n",sizeof(Student);
"b is \"%s\", age %d.\n",b.name,b.age;

ZeroClass(&b);
"After ZeroClass(&b): \"%s\", age %d.\n",b.name,b.age;

//The third arg is an element count, dft 1, so whole arrays work too.
for (i=0; i<3; i++)
{
  ClassCpy(&roster[i],&a);
  roster[i].age=i;
}
ClassCpy(backup,roster,3);
"\nClassCpy(backup,roster,3) copied %d bytes.\n",3*sizeof(Student);
for (i=0; i<3; i++)
  "backup[%d] is \"%s\", age %d.\n",i,backup[i].name,backup[i].age;
