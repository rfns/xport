Include portutils

/// This utility is used to handle file deletions from the server along with removing empty directories left by them.
Class XPort.Util.FileRemover Extends %RegisteredObject
{

Property Entries As list Of %String;

Property Statement As %SQL.Statement;

Property AppPathCache As %String [ Private ];

Method %OnNew() As %Status
{
  set ..Statement = ##class(%SQL.Statement).%New()
  do ..Statement.%PrepareClassQuery("%File", "FileSet")
  return $$$OK
}

Method AddFileToRemoval(filePath As %String) As %Status
{
  return ..Entries.Insert(##class(%File).NormalizeFilename(filePath))
}

Method Run() As %Status
{
  for i=1:1:..Entries.Count() {
    set filePath = ..Entries.GetAt(i)
    set sc = ..Remove(filePath)
    if $$$ISERR(sc) return sc
  }
  return $$$OK
}

Method Remove(path As %String, hasContent As %Boolean = 0) As %Status
{
    
  if path = ..GetWebApplicationPath(path) return $$$OK 
  
  // There's a bug when using Exists for directories, it seems to assume that a directory is also a file.
  // To workaround this, DirectoryExists is also applied because it WILL return 0.
  if '##class(%File).DirectoryExists(path) && ##class(%File).Exists(path) { 
    do ##class(%File).Delete(path) 
  } elseif hasContent = 0 { 
    do ##class(%File).RemoveDirectory(path)
  }
    
  set path = $piece(path, $$$OSSlash, 1, *-1)
  set r = ..Statement.%Execute(path)
  set hasContent = 0
    
  if r.%Next(.sc) {
    if $$$ISERR(sc) return sc
    set hasContent = 1
  }  
  return ..Remove(path, hasContent)
}

ClassMethod RemoveOne(filePath As %String) As %Status
{
  set remover = ..%New()
  $$$QuitOnError(remover.AddFileToRemoval(filePath))
  return remover.Run()
}

Method GetWebApplicationPath(filePath As %String) As %String
{
     
  if ..AppPathCache '= "" return ..AppPathCache
  
  new $namespace 
  set $namespace = "%SYS"
  
  set rows = ##class(%SQL.Statement).%ExecDirect(, "SELECT TOP 1 Path FROM SECURITY.APPLICATIONS WHERE ? %STARTSWITH Path ORDER BY LEN(PATH) DESC", filePath)
  if rows.%Next() {
    set path = ##class(%File).NormalizeFilename(rows.%Get("Path"))
    set ..AppPathCache = path
    return path
  }
  return ""
}

}

