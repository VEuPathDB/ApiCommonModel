<?xml version="1.0" encoding="ISO-8859-1"?>
<!-- Edited by XMLSpy® -->
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

	<xsl:template match="/">
		<html>
			<body>
				<h1>Data Source Attributions</h1>


				<hr></hr>
				<xsl:for-each select="dataSourceAttributions/dataSourceAttribution">
					<xsl:variable name="relativeNode" select="." />

					<h3>
						<xsl:value-of select="displayName"
							disable-output-escaping="yes" />
					</h3>
					<dl>
						
							<dt><b>Description:</b></dt>
						
						<dd>
							<xsl:value-of select="description"
								disable-output-escaping="yes" />
						</dd>

						
							<dt><b>Short Description:</b></dt>
						
						<dd>
							<xsl:value-of select="summary"
								disable-output-escaping="yes" />
						</dd>

						
							<dt><b>Display Category (Optional):</b></dt>
						
						<dd>
							<xsl:value-of select="displayCategory"
								disable-output-escaping="yes" />
						</dd>

						
							<dt><b>Protocol:</b></dt>
						
						<dd>
							<xsl:value-of select="protocol"
								disable-output-escaping="yes" />
						</dd>

						
							<dt><b>Caveat:</b></dt>
						
						<dd>
							<xsl:value-of select="caveat"
								disable-output-escaping="yes" />
						</dd>

						
							<dt><b>Acknowledgement:</b></dt>
						
						<dd>
							<xsl:value-of select="acknowledgement"
								disable-output-escaping="yes" />
						</dd>

						
							<dt><b>ReleasePolicy:</b></dt>
						
						<dd>
							<xsl:value-of select="releasePolicy"
								disable-output-escaping="yes" />
						</dd>


						
							<dt><b>Pubmed IDs:</b></dt>
						
						<dd>
							<xsl:for-each select="./publications/publication/@pmid">
								<xsl:value-of select="." disable-output-escaping="yes" />
								<br />
							</xsl:for-each>
						</dd>



							<dt><b>Contacts:</b></dt>
						
						<dd>
							<xsl:for-each select="./contacts/contact">
								<xsl:value-of select="name" disable-output-escaping="yes" />
								<xsl:if test="string-length(institution) &gt; 0">
								  (<xsl:value-of select="institution" disable-output-escaping="yes" />)
								</xsl:if>
								<br />
							</xsl:for-each>
						</dd>


					</dl>


					<hr></hr>
				</xsl:for-each>
			</body>
		</html>
	</xsl:template>
</xsl:stylesheet>
