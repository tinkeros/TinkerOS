Bool DrvMounted(I64 drv_let)
{//Returns true if drv_let is mounted
  I64 i;
  CDrv *dv=dv=blkdev.drvs;
  for (i=0; i<DRVS_NUM; i++)
  {
    if (dv->dv_signature==DRV_SIGNATURE_VAL)
    {
      if (drv_let==Drv2Let(dv))
      {
        return TRUE;
      }
    }
    dv++;
  }
  return FALSE;
}
