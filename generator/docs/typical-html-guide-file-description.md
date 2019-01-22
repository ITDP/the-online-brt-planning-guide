Every generated html page (in folder .generated for the standard settings described) has:
self identification between tags <!DOCTYPE html>
- INITIAL COMMENT between tags <!-- and --> : with details about how the file was generated
<html>
- HEAD between tags  <head> and  </head> with:
  - information to browser about the encoding: <meta charset="utf-8"> 
  - information to browser about title to show on the tab and window bar: <title>Chapter 29: Pedestrian Access</title>
  - information to browser about behaviour (to responsiveness) <meta name="viewport" content="width=device-width, initial-scale=1.0">
  - information to browser about referenced contents (to assist linking) <base href=".." id="docbase" x-rel-path="pedestrian-access/" >
  - formatting (style) information:
    -- normalize (for setting defaults (browsers have some differences) <link href="https://cdnjs.cloudflare.com/ajax/libs/normalize/4.0.0/normalize.min.css" rel="stylesheet" type="text/css">
    -- custom css with the content of guide/style.css in a different name for each version of the file (to assure current version is used) <link href="assets/f441321e439cda47010df9261d9449df3dcdd922.css" rel="stylesheet" type="text/css">
    (To read the css file:
        - elements of html are the first thing named between tags (html, header, p, a (anchor for links?) ...)
          -- in html you find: `<element-type-name> text that is the element content normally is displayed with element properties </element-type-name>`
          -- in css you find ```
                            element-type-name { 
                                property-name: property-value-properly-defined; 
                                other-property-name: other-property-value-properly-defined;
                            }
                            ```
        - class is a group of elements (for share style same properties/functions) and id is to give a name to an unique element of the document/page
          -- in html you read: '<element-type-name class="element-class-name"> or  '<element-type-name id="element-id">
          -- in css you read: ``` .class-name { ...; ...;  } or #id
        - to responsiveness the elements are listed inside the media (screen, print, tv) condition (width, ratio, number of colors...) brackets
          -- there are three states:
             --- three column-mode (min-width1240): 
                1. table of contents to navigation
                2. text or medium figure/table
                3. small figure/table
                2+3 large figure/table

             --- two colunm mode (max width)
                1. table of contents to navigation (from burguer menu button)
                1. text or medium figure/table
                2. small figure/table
                1+2 large figure/table
                
             --- one column-mode
                - table of contents from burguer (wase in the bottom)
                - figures (are getting to big) and text in the same column

  )      


    -- specified fonts source <link href="https://fonts.googleapis.com/css?family=PT+Serif:400,400italic,700italic,700|PT+Sans:400,400italic,700,700italic" rel="stylesheet" type="text/css">
  - Scripts:
     -- Jquery library (it makes easier to write other scripts that manipulate the html content that browser shows) <script src = "https://ajax.googleapis.com/ajax/libs/jquery/2.1.0/jquery.min.js" ></script>
     -- MathJax library: it is the script that "draws" the formulas on the page
        --- config script: to use the library it is first provided another script that describes 
        customized behaviour expected for this particular page (all the guide pages have the same descripion);
        that is the code between the tags <script type="text/x-mathjax-config"> and </script>
        --- mathjax properly: <script async src="https://cdn.mathjax.org/mathjax/latest/MathJax.js?config=TeX-AMS_CHTML" ></script>
- BODY between tags  <body> and  </body> with:
  - the HEADER between tags <header> and  </header>: that contains the "breadcrumbs" that shows the context where the page is found within the guide structure
    
    It is a list (displayed horizontally by css -- li.jump-to-nav displayed only if screen is narrow, i.e, bellow 1240 ) 
   with links -- anchor elements? -- to the other pages (chapters don't have html extension anymore) emphasized (shouldn't this be let to css)

  - the noscript section between tags <noscript> and </noscript>
        It is a div to be shown if JavaScript is not enabled. If script run the class of the div ("js-required-banner") has its display-property changed to "none"

  - the datapos property provides information for the source file that provided the information being displayed, to facilitate location for edition.

  - div container and col-text are to control responsiveness (beyond 1240px : col-text has a left margin and container has a max size)

  - div nav

  there are two scripts at the bottom of the page... to be loaded by last (saved as assets, that have an unique name for each version)
  the first set up the variable __manu_toc_data__: an html of the complete table of contents (completely expanded with unordered lists inside unordered lists where the items are the links to the file tree)
  the second one is the java script saved in bin/bundle/html.js that is  generated by Haxe from src/html/script/Main.hx and has 2 functions:
    - drawNav(e:Event) trims thee complete table of contents in accordance to the location of the current page, nav will be the last thing draw
    - 

