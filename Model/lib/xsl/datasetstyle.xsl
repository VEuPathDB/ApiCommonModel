<?xml version="1.0" ?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" >

<!-- / forward slash is used to denote a patern that matches the root node of the XML document -->
<xsl:template match ="/" >
  <html>
    <head>
      <title> Dataset Classes </title>
    </head>
    <body>
      <xsl:apply-templates />
    </body>
  </html>
</xsl:template>



<xsl:template match="datasetClasses" >
  
  <table border="1" >
    <tr bgcolor = "#cccccc" >
      <th>Class</th>
      <th>Purpose</th>
      <th>Category</th>
      <th>GraphFile</th>
      <th>Properties</th>
      <th>Resource</th>

    </tr>
    
    
    <xsl:for-each select="datasetClass" >
      <tr>
        <td> <xsl:value-of select="@class" /> </td>
        <td> <xsl:value-of select="purpose" /> </td>
        <td> <xsl:value-of select="@category" /> </td>
        <td> <xsl:value-of select="graphPlanFile/@name" /> </td>
        <td><table>
           <xsl:for-each select="prop" >
             <tr>
               <td>
                 <xsl:value-of select="@name" />
               </td>
             </tr>
           </xsl:for-each>
         </table>
        </td>
        <td><table border="1">
              <tr>
                <td>Resource</td>
                <td>Version</td>
                <td>Plugin</td>
                <td>Scope</td>
                <td>OrgAbbrev</td>
              </tr>
              <tr>
                <td><xsl:value-of select="resource/@resource" /> </td>
                <td><xsl:value-of select="resource/@version" /> </td>
                <td><xsl:value-of select="resource/@plugin" /> </td>
                <td><xsl:value-of select="resource/@scope" /> </td>
                <td><xsl:value-of select="resource/@organismAbbrev" /> </td>
              </tr>
              <tr>
                <td>manualGet: </td>
                <td colspan="4"><xsl:value-of select="resource/manualGet/@fileOrDir" /></td>
              </tr>
              <tr>
                <td>pluginArgs: </td>
                <td colspan="4"><xsl:value-of select="resource/pluginArgs" /></td>
              </tr>
            </table>
        </td>
      </tr>
    </xsl:for-each>
  </table>
</xsl:template >
</xsl:stylesheet >
  
  

