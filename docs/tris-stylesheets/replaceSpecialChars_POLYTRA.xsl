<?xml version="1.0"?>
<xsl:stylesheet exclude-result-prefixes="xsl" version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
	
	<xsl:output indent="yes" encoding="UTF-8" method="xml" omit-xml-declaration="yes"/>	
	
	<xsl:template match="/">
		<xsl:apply-templates/>
	</xsl:template>
	<xsl:template match="@*|node()">
		<xsl:copy>
			<xsl:apply-templates select="@*|node()"/>
		</xsl:copy>
	</xsl:template>
	<xsl:template match="text()">
		<xsl:value-of select="replace(., '&#174;', '(R)')"/>
		<xsl:apply-templates select="@* | *"/>
	</xsl:template>
	<xsl:template match="attribute()">
		<xsl:attribute name="{local-name()}">
			<xsl:value-of select="replace(., '&#174;', '(R)')"/>
		</xsl:attribute>
		<xsl:apply-templates select="@* | *"/>
	</xsl:template>
	
</xsl:stylesheet>
