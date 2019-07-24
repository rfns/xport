Class XPort.Installer Extends %Projection.AbstractProjection
{

Parameter NAME = "/xport/api";

Projection Installer As XPort.Installer;

ClassMethod CreateProjection(classname As %String, ByRef parameters As %String, modified As %String, qstruct) As %Status
{
  return ..CreateHTTPAPI()
}

ClassMethod RemoveProjection(classname As %String, ByRef parameters As %String, recompile As %Boolean, modified As %String, qstruct) As %Status
{
 
  return ..RemoveHTTPAPI()
}

ClassMethod CreateHTTPAPI() As %Status [ Private ]
{
   
  #define DownloadIfRequired(%class, %url) $s('##class(%Dictionary.CompiledClass).%ExistsId(%class): ..DownloadExternalDependency(%url), 1: 1)
  
  write !, ">> Checking if Port is available ..."  
  set flag = $$$DownloadIfRequired("Port.Util", "https://github.com/rfns/port/raw/master/port-prod.xml")   
  else  if flag = 0 write !, " >> Aborted due to errors while downloading the dependencies."
  
  write !, ">> Checking if Frontier is available ..."
  if flag = 1 set flag = $$$DownloadIfRequired("Frontier.Router", "https://github.com/rfns/frontier/raw/master/frontier-prod.xml")
  else  if flag = 0 write !, ">> Aborted due to errors while downloading the dependencies."   
  
  set targetNamespace = $namespace
  
  write !, ">> Port and Frontier are installed. Proceeding ... "
  write !, ">> Creating XPort HTTP API on namespace the "_targetNamespace_" ..."   
  
  new $namespace  
  set $namespace = "%SYS"
  
  if ##class(Security.Applications).Exists(..#NAME) {
    write !, ">> XPort HTTP API already exists. Aborted."
    return $$$OK
  }
  
  set properties("CookiePath") = ..#NAME
  set properties("DispatchClass") = "XPort.API"
  set properties("EventClass") = "Frontier.SessionEvents"
  set properties("NameSpace") = targetNamespace
  set properties("UseCookies") = 2
  set properties("AutheEnabled") = 64
  
  $$$QuitOnError(##class(Security.Applications).Create(..#NAME, .properties))
  write !, ">> The XPort HTTP API has been created with success."
  return $$$OK
}

ClassMethod RemoveHTTPAPI() As %Status
{
  new $namespace
  set $namespace = "%SYS"
  
  if '##class(Security.Applications).Exists(..#NAME) return $$$OK
  write !, ">> Removing XPort HTTP API "_..#NAME_" ..."
  
  $$$QuitOnError(##class(Security.Applications).Delete(..#NAME))
  write !, ">> The XPort HTTP API has been removed with success."
  
  return $$$OK
}

ClassMethod DownloadExternalDependency(url As %String) As %Boolean
{
  try {
    do ..CreateSSLConfig()
    do ##class(%Net.URLParser).Parse(url, .components)
  
    set http = ##class(%Net.HttpRequest).%New()
    set http.Server = components("host")
    set http.Https = (components("scheme") = "https")
    set http.SSLConfiguration = $select(http.Https : "XPort SSL Configuration", 1: "")
 
    write !, ">> Downloading external dependency from "_url
    $$$ThrowOnError(http.Get(components("path")))
  
    set temp = ##class(%File).TempFilename("xml")
    set content = http.HttpResponse.Data
    
    write !, ">> Loading and compiling manifest ... "
    $$$ThrowOnError($System.OBJ.LoadStream(content, "cku /nodisplay"))
  } catch (ex) {
    set sc = ex.AsStatus()
    
    if $$$ISERR(sc) {
      write !, ">> FATAL: The failed to download external dependency from "_url_". Error: "_$System.Status.GetErrorText(sc)
      return 0
    }
  }
  
  return 1
}

ClassMethod CreateSSLConfig()
{
   new $namespace
   set $namespace = "%SYS"
   
   write !, ">> Creating SSL Configuration ..."
   
   do ##class(Security.SSLConfigs).Get("XPort SSL Configuration", .p)
   if $data(p) quit
   
   set p("CipherList")="ALL:!aNULL:!eNULL:!EXP:!SSLv2"
   set p("CAFile")=""
   set p("CAPath")=""
   set p("CRLFile")=""
   set p("CertificateFile")=""
   set p("CipherList")="ALL:!aNULL:!eNULL:!EXP:!SSLv2"
   set p("Description")=""
   set p("Enabled")=1
   set p("PrivateKeyFile")=""
   set p("PrivateKeyPassword")=""
   set p("PrivateKeyType")=2
   set p("Protocols")=24
   set p("SNIName")=""
   set p("Type")=0
   set p("VerifyDepth")=9
   set p("VerifyPeer")=0
   
   do ##class(Security.SSLConfigs).Create("XPort SSL Configuration", .p)
}

}

