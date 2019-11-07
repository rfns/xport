# API

Before you proceed __XPort's__ Keep in mind that most of the API requires the request to be authenticated, except for the ones listed at [Core](https://github.com/rfns/xport/new/master?readme=1#core),

The authentication is based on `Basic` authorization, so it would be something like this:

```
Authorization: Basic `b64encode(cacheUsername:cachePassword)`
```

> __NOTE:__ Remember that the provided credentials must be from a user that has the `%Development` role.

## Core

### HEAD /ping

_Description:_ Returns HTTP 200 OK if the API is alive and ready to receive requests, can be used for health checks.

### GET /info

_Description:_ Returns the information regarding the current XPort installation.

## Projects

### GET /namespaces/:namespace/projects

_Description:_ Retrieves a list of projects in the current `:namespace`.

_Response_:

```json
{
  "projects": [
    {
      "name": "XPort",
      "has_items": true
    }
  ]
}
```

### DELETE /namespaces/:namespace/projects/:project

_Description:_ Deletes the current :project from :namespace if that project is empty.

### GET /namespaces/:namespace/projects/:project/xml

_Description_: Returns a project XML which is compatible with older Caché versions (that don't support UDL).

_Response_:

```json
{
  "xml": "..."
}
```

### POST /namespaces/:namespace/projects/:project/compile

_Description_: Compiles the current `:project`.

_Response_:

```json
{
  "log": ["..."],
  "errors": [
    {
      "internal_code": 5475,
      "message": "...",
      "origin": {
        "internal_code": 5030,
        "message": "..."
      }
    }
  ]
}
```

### PATCH /namespaces/:namespace/projects/:project/repair

_Description_: Looks for faulty items and/or corrupted item entries while fixing the project.

_Response_:

```json
{
  "repaired": true
}
```

## Items

### POST /namespaces/:namespace/projects/:project/items/sources/pick

_Description_: Picks a set of items and their sources from the `:project`.

_Request:_

```json
{
  "files": [
    "cls/XPort/API/Projects/Items.cls",
    "int/myroutine.int",
    "inc/xport.inc",
    "public/csp/dev/my/photo.png"
  ]
}
```

_Response_:

```json
{
  "success": [
    {
      "name": "Xport.API.Project.Items.cls",
      "content": ["..."],
      "binary": false,
      "path": "/CacheProjects/DEV/xport/cls/API/Projects/Items.cls",
      "file_name": "Items.cls"
    },
    {
      "name": "xport.inc",
      "content": ["..."],
      "binary": false,
      "path": "/CacheProjects/DEV/xport/inc/xport.inc",
      "file_name": "xport.inc"
    },
    {
      "name": "csp/dev/my/photo.png",
      "content": ["..."],
      "binary": true,
      "path": "/CacheProjects/DEV/xport/public/csp/dev/my/photo.png",
      "file_name": "photo.png"
    }
  ],
  "failure": {
    "header": "Failed to get the sources from the following items: ",
    "items": [
      {
        "item_name": "myroutine.inc",
        "error": {
          "internal_code": 5001,
          "message": "..."
        }
      }
    ]
  },
  "has_errors": true
}
```

### GET /namespaces/:namespace/projects/:project/items/sources/list?page=1&size=40

_Description_: Retrieves a list of items and their source codes belonging to `:project` in `:namespace`.

_Response:_

```json
{
  "more": true,
  "has_errors": true,
  "success": [
    {
      "index": 1,
      "name": "XPort.API.cls",
      "content": ["..."],
      "binary": false,
      "path": "/CacheProjects/DEV/xport/cls/XPort/API.cls",
      "file_name": "API.cls"
    }
  ],
  "failure": {
    "header": "Failed to get the sources from the following items: ",
    "items": [
      {
        "item_name": "myroutine.inc",
        "error": {
          "internal_code": 5001,
          "message": "..."
        }
      }
    ]
  }
}
```

### GET /namespaces/:namespace/projects/:project/items/count

_Description:_ Retrieves the number of items that belongs to the `:project`.

_Response_:

```json
{
  "count": 50
}
```

### POST /namespaces/:namespace/projects/:project/items/publish

_Description_: Publishes a document and its content to `:project`.

_Request_:

```json
{
  "compilerOptions": "cku",
  "items": [
    {
      "path": "c:\\CacheProjects\\DEV\\xport\\cls\\XPort\\API\\Test.cls",
      "content": ["..."]
    }
  ]
}
```

_Response:_

```json
{
  "success": [
    {
      "name": "XPort.API.Test.cls",
      "content": ["..."],
      "path": "..."
    }
  ],
  "has_errors": true,
  "warning": null,
  "failure": {
    "header": "Failed to publish the following items: ",
    "items": ["..."]
  }
}
```


### POST /namespaces/:namespace/projects/:project/items/remove

_Description:_ Removes (but doesn't delete) a list of items from the `:project`.

_Request_:

```json
[
  "cls/Xport/XPort/API/Test.cls"
]
```

_Response_:
```json
{
  "success": [
    "XPort.API.Test.cls"
  ],
  "has_errors": false,
  "failure": {
    "header": "Failed to remove some items: ",
    "items": ["..."]
  }
}
```

### POST /namespaces/:namespace/projects/:project/items/delete

_Description:_ Deletes list of items and their source codes while also removing them from the `:project`.

_Request_:

```json
[
  "cls/Xport/XPort/API/Test.cls"
]
```

_Response_:
```json
{
  "success": [
    "XPort.API.Test.cls"
  ],
  "has_errors": false,
  "failure": {
    "header": "Failed to delete some items: ",
    "items": ["..."]
  }
}
```
