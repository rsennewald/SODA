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

###############################################################################
# Staf return codes:
###############################################################################
   STAFOk = 0
   STAFInvalidAPI = 1
   STAFUnknownService = 2
   STAFInvalidHandle = 3
   STAFHandleAlreadyExists = 4
   STAFHandleDoesNotExist = 5
   STAFUnknownError = 6
   STAFInvalidRequestString = 7
   STAFInvalidServiceResult = 8
   STAFREXXError = 9
   STAFBaseOSError = 10
   STAFProcessAlreadyComplete = 11
   STAFProcessNotComplete = 12, 
   STAFVariableDoesNotExist = 13
   STAFUnResolvableString = 14
   STAFInvalidResolveString = 15
   STAFNoPathToMachine = 16
   STAFFileOpenError = 17
   STAFFileReadError = 18
   STAFFileWriteError = 19
   STAFFileDeleteError = 20
   STAFNotRunning = 21
   STAFCommunicationError = 22
   STAFTrusteeDoesNotExist = 23
   STAFInvalidTrustLevel = 24
   STAFAccessDenied = 25
   STAFRegistrationError = 26
   STAFServiceConfigurationError = 27
   STAFQueueFull = 28
   STAFNoQueueElement = 29
   STAFNotifieeDoesNotExist = 30
   STAFInvalidAPILevel = 31
   STAFServiceNotUnregisterable = 32
   STAFServiceNotAvailable = 33
   STAFSemaphoreDoesNotExist = 34
   STAFNotSemaphoreOwner = 35, 
   STAFSemaphoreHasPendingRequests = 36
   STAFTimeout = 37
   STAFJavaError = 38
   STAFConverterError = 39
   STAFNotUsed = 40
   STAFInvalidObject = 41
   STAFInvalidParm = 42
   STAFRequestNumberNotFound = 43
   STAFInvalidAsynchOption = 44
   STAFRequestNotComplete = 45
   STAFProcessAuthenticationDenied = 46
   STAFInvalidValue = 47
   STAFDoesNotExist = 48
   STAFAlreadyExists = 49
   STAFDirectoryNotEmpty = 50
   STAFDirectoryCopyError = 51
   STAFDiagnosticsNotEnabled = 52
   STAFHandleAuthenticationDenied = 53
   STAFHandleAlreadyAuthenticated = 54
   STAFInvalidSTAFVersion = 55
   STAFRequestCancelled = 56
   STAFCreateThreadError = 57
   STAFMaximumSizeExceeded = 58
   STAFMaximumHandlesExceeded = 59
   STAFUserDefined = 4000

###############################################################################
# Import needed staf functions:
###############################################################################
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

