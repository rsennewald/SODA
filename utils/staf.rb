require 'dl/import'
require 'dl/struct'
require 'singleton'

module Staf
   extend DL::Importable
   dlload("libSTAF.so")

   UIPointer = struct [
      "int value"
   ]

   CPPointer = struct [
      "char* value"
   ]

   import("STAFRegister", "unsigned int", ["char*", "unsigned int*"])
   import("STAFUnRegister", "unsigned int", ["unsigned int"])
   import("STAFSubmit", "unsigned int", ["unsigned int", "char*", "char*", 
         "char*", "unsigned int", "char **", "unsigned int*"])

###############################################################################
# Register -- function
#     This function calls StafRegister.
#
# Input:
#     name: The name of you connection to register with.
#
# Output:
#     returns a hash {'err', 'handle'}, err is the staf return code, and
#     handle is the staf connection handle.
#
###############################################################################
   def Staf.Register(name)
      h = UIPointer.malloc()
      err = nil

      err = sTAFRegister(name, h)

      return {"err" => err, "handle" => h.value}
   end

###############################################################################
# Unregister -- function
#     This function calls StafUnregister.
#
# Input:
#     h: the staf handle to unregister.
#
# Output:
#     returns the staf error code.
#
###############################################################################
   def Staf.Unregister(h)
      err = nil

      err = sTAFUnRegister(h)

      return err
   end

###############################################################################
# Submit -- function
#     This function calls Staf Submit.
#
# Input:
#     h: The staf handle.
#     where: This is where to execute the staf command.
#     service: The staf service to call.
#     request: The request to the staf service.
#
# Output:
#     returns a hash {err, result}, the error is a staf error, and the result
#     is the result from the staf service.
#
###############################################################################
   def Staf.Submit(h, where, service, request)
      err = nil
      result = CPPointer.malloc()
      result_len = UIPointer.malloc()

      err = sTAFSubmit(
            h,
            where, 
            service, 
            request, 
            request.length,
            result,
            result_len)

      return {'result' => result.value, 'err' => err}
   end

end

