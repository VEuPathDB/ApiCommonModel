<?xml version="1.0" ?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" >

<xsl:output method="html" doctype-system="about:legacy-compat" />

<!-- / forward slash is used to denote a patern that matches the root node of the XML document -->
<xsl:template match ="/" >
  <html>
    <head>
      <title> Dataset Classes </title>
      <link rel="stylesheet" href="http://code.jquery.com/ui/1.10.3/themes/smoothness/jquery-ui.css"/>
      <style type="text/css">
        body {
          min-width: 900px;
          font-family: helvetica, arial, sans;
          font-size: 95%;
        }
        #toc ul, #content {
          overflow-y: scroll;
        }
        #toc {
          float: left;
          min-width: 280px;
          width: 280px;
          padding-right: 10px;
          word-wrap: break-word;
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
        #handle {
          border-right: 1px solid #ccc;
          border-left: 1px solid #ccc;
          width: 4px;
          background-color: whitesmoke;
          right: 0px;
        }
        #handle:hover {
          background-color: #ccc;
        }
        #content {
          margin-left: 290px;
          padding-left: 5px;
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
        <xsl:apply-templates mode="toc"/>
        <div id="handle" class="ui-resizable-handle ui-resizable-e"></div>
      </div>
      <div id="content">
        <xsl:apply-templates />
      </div>
      <script src="http://code.jquery.com/jquery-1.9.1.js"></script>
      <script src="http://code.jquery.com/ui/1.10.3/jquery-ui.js"></script>
      <script>
        jQuery(function($) {
          function setHeights() {
            $("#toc ul").height($(window).height() - 20);
            $("#handle").height($(window).height() - 20);
            $("#content").height($(window).height() - 20);
          }
          $("#toc").resizable({ handles: { e: "#handle" } });
          setHeights();
          $(window).on("resize", setHeights);
        });
      </script>
    </body>
  </html>
</xsl:template>

<xsl:template match="datasetClasses" mode="toc">
  <ul>
    <xsl:for-each select="datasetClass">
      <li><a href="#{@class}"><xsl:value-of select="@class"/></a></li>
    </xsl:for-each>
  </ul>
</xsl:template>

<xsl:template match="datasetClasses" >

    <xsl:for-each select="datasetClass" >
      <a name="{@class}"/>
      <dl>
        <dt>Class</dt>
        <dd> <xsl:value-of select="@class" /> </dd>

        <dt>Purpose</dt>
        <dd> <xsl:value-of select="purpose" /> </dd>

        <dt>Category</dt>
        <dd> <xsl:value-of select="@category" /> </dd>

        <dt>GraphFile</dt>
        <dd> <xsl:value-of select="graphPlanFile/@name" /> </dd>

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

        <dt>Resource</dt>
        <dd><table border="1">
              <tr>
                <th>Resource</th>
                <th>Version</th>
                <th>Plugin</th>
                <th>Scope</th>
                <th>OrgAbbrev</th>
              </tr>
              <tr>
                <td><xsl:value-of select="resource/@resource" /> </td>
                <td><xsl:value-of select="resource/@version" /> </td>
                <td><xsl:value-of select="resource/@plugin" /> </td>
                <td><xsl:value-of select="resource/@scope" /> </td>
                <td><xsl:value-of select="resource/@organismAbbrev" /> </td>
              </tr>
              <tr>
                <th>manualGet: </th>
                <td colspan="4"><xsl:value-of select="resource/manualGet/@fileOrDir" /></td>
              </tr>
              <tr>
                <th>pluginArgs: </th>
                <td colspan="4"><xsl:value-of select="resource/pluginArgs" /></td>
              </tr>
            </table>
        </dd>
      </dl>
      <hr/>
    </xsl:for-each>
</xsl:template >
</xsl:stylesheet >
  
  

