Class XPort.API.Tasks.XML Extends Frontier.Router
{

XData UrlMap
{
<Routes>
    <Route Url="/export" Method="POST" Call="ExportXML" />
    <Route Url="/import" Method="POST" Call="ImportXML" />
  </Routes>
}

ClassMethod ExportXML(namespace As %String, payload As %DynamicObject) As %DynamicObject
{
  set encoding = ##class(%Net.Charset).GetTranslateTable(payload.encoding)
  set %frontier.Response.Timeout = 600
  set projects = ""

  set xml = ##class(XPort.Util.NamespaceCall).ExportSelectionToXML(namespace, payload.items, encoding)
  return { "xml": (xml) }
}

}

