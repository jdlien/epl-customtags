# CustomTags
EPL's ColdFusion custom tags and ColdFusion components used in Apps Legacy and www2.epl.ca.

**This is a redacted public-facing version of the repo that omits commit history and some legacy files.**

## JavaLoader
3rd party library for loading Java classes. Used for markdown and barcode/QR code generation.

## AppInput.cfc
Generates a variety of input types for use in forms that support validation from the @jdlien/validator NPM package. This is the preferred way to generate form inputs. input.cfm is a customtag to use this component in a cftags/html environment.

## filesInput.cfm
Shows an input for uploading files that supports drag and drop and instantaneous realtime upload with datus display. Allows for many options, see https://apps.epl.ca/web/design/#cat7 for more information on how to use this.

## filesMove.cfm
Handles moving a temporary file upload from a cf_FilesInput tag into its final resting place after a form submission. Allows for many options, see https://apps.epl.ca/web/design/#cat7 for more information on how to use this.

## filesList.cfm
Lists the files in a folder, formatted in a nice way, allows for deletion given requisite permission. Allows for many options, see https://apps.epl.ca/web/design/#cat7 for more information on how to use this.

## FilterTable.cfc
The server-side component for the powerful FilterTable CRUD interface that generates searchable/filterable table views for database tables and views. See `FilterTable.md` for full documentation on how to use this.

## FilterTable.md
Documentation for the FilterTable component.

## FilterTableSettings.cfc
A class that contains the session-scoped objects used to store user settings for each FilterTable instance, like search, filter, and sort settings. This is used by FilterTable.cfc.

## formInput.cfm
Custom Tag that encapsulates AppInput for use in cftags/html environments. Exactly like input.cfm except that it renders the input inside a div with class of `form-item` which puts generated content in a grid.

## input.cfm
Custom tag that generates a variety of input types for use in forms that support validation from the @jdlien/validator NPM package. This is the preferred way to generate form inputs. This is a wrapper for AppInput.cfc for use in cftags/html environments.

## IpUtil.cfc
A ColdFusion component that contains a variety of functions for working with IP addresses. Includes functions for converting an IP address to decimal and vice-versa, converting subnet masks to and from CIDR notation, and checking determining the broadcast address for a given IP and subnet mask combination.

## PageSettings.cfc
A bean that contains settings used in the AppsHeader.cfm for most pages which includes things like title, JS and CSS files, and other settings. An instance of this called `app` is created for any page using the header.

## QRBarcode.cfc
Generates QR codes and barcodes given a string. Uses the JavaLoader library to load the zxing library.

## SymWS.cfc
A ColdFusion component that handles communication with the Symphony Web Services API used to get data from the ILS. This makes it easy to retrieve patron information, create temporary library cards, perform searches, authenticate users, and more.

## UserInfo.cfc
A bean that contains information about the current user. This is used by applications to get information about users. The current user has a session.user object that is an instance of this bean.

## Util.cfc
A collection of utility functions used by many applications. This includes things like generating random strings, writing as JSON, converting weekdays to month, and converting markdown to HTML. If you have a small, standalone utility function that can be used across multiple pages, this is a good place to put it. See Util.md for complete documentation