Include portutils

Class XPort.API.Documents Extends Frontier.Router
{

XData UrlMap [ XMLNamespace = "http://github.com/rfns/xport" ]
{
<Routes>
<Route Url="/find" Method="GET" UseAuth="true" Call="FindDocuments"/>
<Route Url="/raw/?(.*)?" Strict="false" UseAuth="false" Method="GET" Call="GetRawFile"/>
<Route Url="/preview/?(.*)?" Strict="false" Method="GET" Call="PreviewDocument" />
<Route Url="/references" Method="GET" Call="GetDocumentReferences" />
</Routes>
}

ClassMethod GetRawFile(namespace As %String) As %Status
{
  
  set path = $$GetWebApplicationServingPath(.webApp)
  return %frontier.Files.ServeFile(path)
  
GetWebApplicationServingPath(webApp)
  // Makes sure we don't fetch the /public part
  set match = $$$LPadProvidedSlash(%frontier.Matches(1), "/")
  if $extract(match, 1, 7) = "/public" set match = $replace(match, "/public", "") 
  
  new $namespace
  set $namespace = "%SYS"
  
  set r = ##class(%SQL.Statement).%ExecDirect(, "SELECT TOP 1 Path, Name FROM SECURITY.APPLICATIONS WHERE NAMESPACE = ? AND PATH IS NOT NULL AND ? %STARTSWITH NAME ORDER BY LENGTH(PATH) DESC", namespace, match)
  
  if r.%Next(.sc) {
    $$$ThrowOnError(sc) 
    set appName = r.%Get("Name") 
    set appPath = r.%Get("Path")
    return appPath_$replace(match, appName, "")
  }  
  return ""
}

ClassMethod FindDocuments(namespace As %String, pattern As %String, limit As %Integer = 50) As %DynamicObject
{
  set s = ##class(%SQL.Statement).%New()
  $$$ThrowOnError(s.%PrepareClassQuery("%RoutineMgr", "StudioOpenDialog"))
  set c = s.%Execute(pattern,,,1,1)

  set matches = []
  set hits = 0

  set appPath = ""

  while c.%Next(.sc) {
    $$$ThrowOnError(sc)

    if hits > limit quit
    set hits = hits + 1

    set name = c.%Get("Name")
    set type = c.%Get("Type")

    if type = 9 || (type = 7) continue

    do matches.%Push(name)
  }

  return { "matches": (matches) }
}

ClassMethod PreviewDocument(namespace As %String) As %DynamicObject
{
  set match = $$$LPadProvidedSlash(%frontier.Matches(1), "/")
  set itemName = ##class(Port.Util).PathToItem(match, namespace)
  set code = ##class(XPort.Util.NamespaceCall).RetrieveItemSourceCode(namespace, itemName, .binary)
  set ext = $piece(itemName, ".", *)  
  return { "binary": ($$$FormatBoolean(binary)), "preview": (code) }
}

ClassMethod GetDocumentReferences(namespace As %String, expression As %String, pattern As %String, includeSystemDocs As %Boolean = 1, wholeWords As %Boolean = 0, caseSensitive As %Boolean = 0, max As %Integer = 50, filter As %String = "", wild As %Boolean = 0) As %DynamicObject
{
  set references = []
  $$$ThrowOnError(##class(Frontier.Shared.Utilities).CallAndCapture("%Studio.Project", "FindInFiles", .output, expression, pattern, includeSystemDocs, wholeWords, caseSensitive, max, filter, wild))

  while 'output.AtEnd {
    set line = output.ReadLine()
    if line = "" continue
    do references.%Push(line)
  }
  return { "references": (references) }
}

}

