# XPort

> __WARNING:__ This is a work-in-progress and it might not be ready for production usage.

__XPort__ is a HTTP adapter which uses the [Port](https://github.com/rfns/port) engine. It aims to bring _Port_'s core principle
while removing impeding barriers to work with [InterSystems Caché®](https://www.intersystems.com/products/cache/) source codes. Think of it
as an alternative to the current [Atelier API](https://docs.intersystems.com/latest/csp/docbook/DocBook.UI.Page.cls?KEY=GSCF_tutorial).

It's made to be used with editors like [Visual Studio Code](https://code.visualstudio.com/) but it can also be used for general purposes.

# Features

* Optimized for big projects (5000+ items).
* Multiple source code publication and retrieval, including files and binaries.
* Static files preview, including binaries.
* Mechanisms to prevent item duplication and accidental deletions.
* Project compilation and repair.
* One namespace for all: installing once is enough to work with codes on every namespace.
* Authentication based on Caché username/password and %Development role.

# Requirements

* InterSystems Caché® 2017 or later, although late 2016 could work as well (not tested).
* [Port](https://github.com/rfns/port).
* [Frontier](https://github.com/rfns/frontier).

# Installation

The fastest way to install __XPort__ is to import and compile the
[xport-installer](https://raw.githubusercontent.com/rfns/xport/master/xport-install.xml), this
will install _Port_ and _Frontier_ as well. Just make sure that your instance can access the internet.

After installing it, navigate to [this link](http://localhost:57772/xport/api/info).
If everything is ok, you should see a response link this one:

```json
{
  "version": "0.9.1",
  "application": "/xport/api",
  "namespace": "DEV",
  "dispatcher": "XPort.API"
}
```

# How to use

Users that want to use it should follow the API (not available yet, in development) document.
Meanwhile you might want to check out the [extension](https://github.com/rfns/vscode-xport) that uses it.

# CONTRIBUTING

You can see how to contribute to this project by visiting [this](https://github.com/rfns/xport/blob/master/CONTRIBUTING.md) document.


# LICENSE

[MIT.](https://github.com/rfns/xport/blob/master/LICENSE)
