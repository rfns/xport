Include portutils

Class XPort.API.Documents Extends Frontier.Router
{

XData UrlMap [ XMLNamespace = "http://github.com/rfns/xport" ]
{
<Routes>
<Route Url="/find" Method="GET" UseAuth="true" Call="FindDocuments"/>
<Route Url="/preview/?(.*)?" Strict="false" Method="GET" Call="PreviewDocument" />
<Route Url="/references" Method="GET" Call="GetDocumentReferences" />

</Routes>
}

ClassMethod FindDocuments(namespace As %String, pattern As %String, limit As %Integer = 50) As %DynamicObject
{
  set webAppPath = ##class(Port.Util).FindApplicationWithPhysicalPath(namespace)

  if webAppPath = "" {
    return %frontier.ThrowException("Unable to find a valid web application.")
  }

  set s = ##class(%SQL.Statement).%New()
  $$$ThrowOnError(s.%PrepareClassQuery("%RoutineMgr", "StudioOpenDialog"))
  set c = s.%Execute(pattern,,,1,1)

  set matches = []
  set hits = 0

  while c.%Next(.sc) {
    $$$ThrowOnError(sc)

    if hits > limit quit
    set hits = hits + 1

    set name = c.%Get("Name")
    set type = c.%Get("type")

    if type = 9 || (type = 7) continue

    do matches.%Push(name)
  }

  return {
    "webAppPath": (webAppPath),
    "matches": (matches)
  }
}

ClassMethod PreviewDocument(namespace As %String) As %DynamicObject
{
  set item = $replace("/"_%frontier.Matches(1), ##class(Port.Util).FindApplicationWithPhysicalPath(namespace), "")
  $$$ThrowOnError(##class(Port.Util).MountItemNameFromSourcePath(item, .itemName, namespace))
  set code = ##class(XPort.Util.NamespaceCall).RetrieveItemSourceCode(namespace, "", itemName)

  return { "preview": (code) }
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
