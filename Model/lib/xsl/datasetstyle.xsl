<?xml version="1.0" ?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" >

<xsl:output method="html" doctype-system="about:legacy-compat" />

<!-- / forward slash is used to denote a patern that matches the root node of the XML document -->
<xsl:template match ="/" >
  <html>
    <head>
      <title> Dataset Classes </title>
      <style type="text/css">
        body {
          min-width: 900px;
          font-family: helvetica, arial, sans;
          font-size: 95%;
        }
        #toc, #content {
          overflow-y: scroll;
        }
        #toc {
          float: left;
          width: 280px;
          padding-right: 10px;
          word-wrap: break-word;
          border-right: 1px solid #ccc;
          font-size: 90%;
        }
        #toc ul {
          list-style: none;
          padding-left: 10px;
          margin-left: 0;
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
        #content {
          margin-left: 300px;
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
      </style>
    </head>
    <body>
      <div id="toc">
        <xsl:apply-templates mode="toc"/>
      </div>
      <div id="content">
        <xsl:apply-templates />
      </div>
      <script type="text/javascript">
        function setHeights() {
          var toc = document.getElementById("toc");
          var content = document.getElementById("content");
          toc.style.height = (window.innerHeight) ? window.innerHeight - 20 + "px" :
              document.documentElement.clientHeight - 30 + "px";
          content.style.height = (window.innerHeight) ? window.innerHeight - 20 + "px" :
              document.documentElement.clientHeight - 30 + "px";
        }
        setHeights();
        if (window.addEventListener) {
          window.addEventListener("resize", setHeights);
        } else {
          document.body.attachEvent("onresize", setHeights);
        }
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
          <ul>
           <xsl:for-each select="prop" >
             <li><xsl:value-of select="@name" /></li>
           </xsl:for-each>
         </ul>
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
  
  

