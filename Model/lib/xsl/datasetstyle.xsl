<?xml version="1.0" ?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" >

<xsl:output method="html" doctype-system="about:legacy-compat" />

<!-- / forward slash is used to denote a patern that matches the root node of the XML document -->
<xsl:template match ="/" >
  <html>
    <head>
      <title> Dataset Classes </title>
      <link rel="stylesheet" href="//ajax.googleapis.com/ajax/libs/jqueryui/1.10.3/themes/smoothness/jquery-ui.css"/>
      <style type="text/css">
        body {
          min-width: 900px;
          font-family: helvetica, arial, sans;
          font-size: 95%;
          background-color: #f4f4f4;
        }
        code {
          font-family: monospace;
        }
        h2 {
          border-top: 4px solid red;
          border-bottom: 3px solid orange;
          padding-top: 4px;
          padding-bottom: 4px;
        }
        h3 {
          margin-bottom: 0px;
        }
        h3, dt {
          color: purple;
        }
        #categories, #classes, #content {
          overflow-y: scroll;
        }
        #toc {
          float: left;
          width: 280px;
          padding-right: 10px;
          overflow-x: auto;
          font-size: 90%;
        }
        #toc ul {
          list-style: none;
          padding-left: 10px;
          margin: 0;
        }
        #toc li {
          padding: 1px 0;
        }
        #toc a, #toc a:visited {
          text-decoration: none;
          color: rgb(17,79,192);
        }
        #toc a:hover {
          color: #bb7a2a;
        }
        #toc-handle {
          border-right: 1px solid #ccc;
          border-left: 1px solid #ccc;
          width: 4px;
          right: 0px;
          cursor: ew-resize;
        }
        #categories {
          height: 30%;
        }
        #categories ul {
          padding-bottom: 8px;
        }
        #categories li.active {
          background: #ccc;
        }
        #categories-handle {
          border-top: 1px solid #ccc;
          border-bottom: 1px solid #ccc;
          height: 4px;
          bottom: 0px;
          cursor: ns-resize;
        }
        .ui-resizable-handle {
          background-color: white;
        }
        .ui-resizable-handle:hover {
          background-color: #ccc;
          background-color: whitesmoke;
        }
        #content {
          margin-left: 290px;
          padding-left: 10px;
        }
        #content dt {
          font-weight: bold;
        }
        #content dd {
          margin-left: 10px;
          margin-bottom: 10px;
        }
        #content ul {
          padding-left: 20px;
          margin-left: 0;
        }
        th, td {
          padding: 4px;
          text-align: left;
        }
      </style>
    </head>
    <body>
      <div id="toc">
        <div id="categories">
          <h3>Categories</h3>
          <xsl:apply-templates mode="categories"/>
          <div id="categories-handle" class="ui-resizable-handle ui-resizable-s"></div>
        </div>
        <div id="classes">
          <h3>Classes</h3>
          <xsl:apply-templates mode="classes"/>
        </div>
        <div id="toc-handle" class="ui-resizable-handle ui-resizable-e"></div>
      </div>
      <div id="content">
        <xsl:apply-templates />
      </div>
      <script src="//ajax.googleapis.com/ajax/libs/jquery/1.9.1/jquery.min.js"></script>
      <script src="//ajax.googleapis.com/ajax/libs/jqueryui/1.10.3/jquery-ui.min.js"></script>
      <script>
        jQuery(function($) {
          function setHeights() {
            $("#toc").height($(window).height() - 20);
            $("#classes").height($("#toc").height() - $("#categories").height());
            $("#content").height($(window).height() - 20);
          }
          $("#toc").resizable({ handles: { e: "#toc-handle" } });
          $("#categories").resizable({
            handles: { e: "#categories-handle" },
            resize: function(e, ui) {
              $("#classes").height($("#toc").height() - ui.size.height);
            }
          }).on("scroll", function() {
            var negScrollTop = -$(this).scrollTop();
            $("#categories-handle").css("bottom", negScrollTop);
          });
          setHeights();
          $(window).on("resize", setHeights);
        });

        $("#categories").on("click", ".type-filter", function(e) {
          e.preventDefault();
          var type = $(this).data("type");
          $("#categories li").removeClass("active");
          if (type) {
            $(this).parent().addClass("active");
            $(".datasetClass").show().not("." + type).hide();
            $(".classes li").show().not("." + type).hide();
          } else {
            $(".datasetClass").show();
            $(".classes li").show();
          }
          $("#content").scrollTop(0);
        });
      </script>
    </body>
  </html>
</xsl:template>

<xsl:template match="datasetClasses" mode="categories">
  <ul class="categories">
    <li><a class="type-filter" href="#all">All categories</a></li>
    <xsl:for-each select="datasetClass/datasetLoader/@type[not(.=preceding::datasetClass/datasetLoader/@type)]">
      <li><a class="type-filter" data-type="{.}" href="#{.}"><xsl:value-of select="."/></a></li>
    </xsl:for-each>
  </ul>
</xsl:template>
<xsl:template match="datasetClasses" mode="classes">
  <ul class="classes">
    <xsl:for-each select="datasetClass">
      <li class="{datasetLoader/@type}"><a href="#{@class}"><xsl:value-of select="@class"/></a></li>
    </xsl:for-each>
  </ul>
</xsl:template>

<xsl:template match="datasetClasses" >

    <xsl:for-each select="datasetClass" >
      <div class="datasetClass {datasetLoader/@type}">
        <a name="{@class}"/>
        <h2>Class: <xsl:value-of select="@class" /> </h2>

        <dl>
          <dt>Purpose</dt>
          <dd> <xsl:value-of select="purpose" /> </dd>

          <dt>Category</dt>
          <dd> <xsl:value-of select="@category" /> </dd>

          <dt>GraphTemplateFile</dt>
          <dd> <xsl:value-of select="graphTemplateFile/@name" /> </dd>

          <dt>Properties</dt>
          <dd>
            <table border="1">
             <tr><th>Property</th><th>Description</th></tr>
             <xsl:for-each select="prop" >
               <tr>
                 <td><xsl:value-of select="@name" /></td>
                 <td><xsl:value-of select="." /></td>
               </tr>
             </xsl:for-each>
           </table>
           </dd>

          <xsl:if test="datasetLoader">
            <br/>
            <dt>Dataset loader</dt>
            <dd><table border="1">
                  <tr>
                    <th>DatasetName</th>
                    <th>Version</th>
                    <th>Scope</th>
                    <th>OrgAbbrev</th>
                  </tr>
                  <tr>
                    <td><code><xsl:value-of select="datasetLoader/@datasetName" /></code> </td>
                    <td><code><xsl:value-of select="datasetLoader/@version" /></code> </td>
                    <td><code><xsl:value-of select="datasetLoader/@scope" /></code> </td>
                    <td><code><xsl:value-of select="datasetLoader/@organismAbbrev" /></code> </td>
                  </tr>
                  <tr>
                    <th>manualGet: </th>
                    <td colspan="3"><code><xsl:value-of select="datasetLoader/manualGet/@fileOrDir" /></code></td>
                  </tr>
                  <tr>
                    <th>plugin: </th>
                    <td colspan="3"><code><xsl:value-of select="datasetLoader/@plugin" /></code></td>
                  </tr>
                  <tr>
                    <th>pluginArgs: </th>
                    <td colspan="3"><code><xsl:value-of select="datasetLoader/pluginArgs" /></code></td>
                  </tr>
                </table>
            </dd>
          </xsl:if>
        </dl>
        <br/>
        <br/>
      </div>
    </xsl:for-each>
</xsl:template >
</xsl:stylesheet >
  
  

