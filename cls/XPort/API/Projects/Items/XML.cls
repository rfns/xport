Class XPort.API.Projects.Items.XML Extends Frontier.Router
{

XData UrlMap
{
<Routes>
    <Route Url="/export" Method="POST" Call="ExportXML" />
    <Route Url="/import" Method="POST" Call="ImportXML" />
  </Routes>
}

ClassMethod ExportXML(namespace As %String, project As %String, payload As %DynamicObject) As %DynamicObject
{
  set encoding = ##class(%Net.Charset).GetTranslateTable(payload.encoding)
  set xml = ##class(XPort.Util.NamespaceCall).ExportSelectionToXML(namespace, project, payload.items, encoding)
  return { "xml": (xml) }
}

}

