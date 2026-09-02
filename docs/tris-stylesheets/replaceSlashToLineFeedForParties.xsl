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
		<xsl:call-template name="replaceSlashes">
			<xsl:with-param name="partyType" select="../../@Type"/>
			<xsl:with-param name="parentNodeName" select="name(parent::node())"/>
			<xsl:with-param name="value" select="."/>
		</xsl:call-template>
		<xsl:apply-templates select="@* | *"/>
	</xsl:template>
	<xsl:template match="attribute()">
		<xsl:attribute name="{local-name()}">
			<xsl:value-of select="."/>
		</xsl:attribute>
		<xsl:apply-templates select="@* | *"/>
	</xsl:template>
	
	<xsl:template name="replaceSlashes">
		<xsl:param name="partyType"/>
		<xsl:param name="parentNodeName"/>
		<xsl:param name="value"/>
		
		<xsl:choose>
			<xsl:when test="($partyType = 'DO' or $partyType = 'N1' or $partyType = 'N2') and contains(upper-case($parentNodeName), 'PARTYADDRESS') and upper-case($parentNodeName) != 'PARTYADDRESSNAME1'">
				<xsl:value-of select="replace(replace(replace(normalize-space($value), '//', 'singlesl@ch'), '/', '&#10;'), 'singlesl@ch', '/')"/>
			</xsl:when>
			<xsl:when test="upper-case($parentNodeName) = 'PARTYADDRESSNAME1'">
				<xsl:value-of select="normalize-space($value)"/>
			</xsl:when>
			<xsl:otherwise>
				<xsl:value-of select="$value"/>
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>
	
</xsl:stylesheet>
