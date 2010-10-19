require 'utils/staf'

   err = nil
   result = Staf.Register("test-ruby")
   if (result['err'] != Staf::STAFOk)
      print "(!)Failed calling Register!\n"
      exit(-1)
   end
   print "(*)Registered.\n"

   print "(*)Staf pinging localhost...\n"
   err = Staf.Submit(result['handle'], "local", "ping", "ping")
   if (err['err'] != Staf::STAFOk)
      print "(!)Failed calling: staf local ping ping!\n"
      exit(-1)
   end
   print "(*)Ping result: #{err['result']}.\n"

   Staf.Unregister(result['handle'])
   print "(*)Done.\n\n"

