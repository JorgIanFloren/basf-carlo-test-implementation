<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
	<xsl:output method="xml" version="1.0" encoding="UTF-8" indent="yes"/>	

<xsl:template match="/">
	<xsl:variable name="root">
		<xsl:value-of select="distinct-values(/*:unEdifact/*:interchangeMessage/child::*[BGM or Beginning_of_message]/local-name())"/>
	</xsl:variable>
	<xsl:element name="{$root}">
		<MESSAGE>
			<UNB>
				<E-S001 description="SYNTAX IDENTIFIER">
					<C-0001 description="Syntax identifier">
						<xsl:value-of select="/*:unEdifact/*:UNB/*:syntaxIdentifier/*:id"/>
					</C-0001>
					<C-0002 description="Syntax version number">
						<xsl:value-of select="/*:unEdifact/*:UNB/*:syntaxIdentifier/*:versionNum"/>
					</C-0002>
				</E-S001>
				<E-S002 description="INTERCHANGE SENDER">
					<C-0004 description="sender identification">
						<xsl:value-of select="/*:unEdifact/*:UNB/*:sender/*:id"/>
					</C-0004>
					<C-0008 description="sender identification">
						<xsl:value-of select="/*:unEdifact/*:UNB/*:sender/*:internalId"/>
					</C-0008>
				</E-S002>
				<E-S003 description="INTERCHANGE RECIPIENT">
					<C-0010 description="recipient identification">
						<xsl:value-of select="/*:unEdifact/*:UNB/*:recipient/*:id"/>
					</C-0010>
				</E-S003>
				<E-S004 description="DATE AND TIME OF PREPARATION">
					<C-0017 description="Date of preparation">
						<xsl:value-of select="/*:unEdifact/*:UNB/*:dateTime/*:date"/>
					</C-0017>
					<C-0019 description="Time of preparation">
						<xsl:value-of select="/*:unEdifact/*:UNB/*:dateTime/*:time"/>
					</C-0019>
				</E-S004>
				<E-0020 description="INTERCHANGE CONTROL REFERENCE">
					<xsl:value-of select="/*:unEdifact/*:UNB/*:controlRef"/>
				</E-0020>
			</UNB>
			<xsl:for-each select="/*:unEdifact/*:interchangeMessage">
				<Group0>
					<UNH>
						<E-0062 description="Message Reference Number">
							<xsl:value-of select="*:UNH/*:messageRefNum"/>
						</E-0062>
						<E-S009 description="Message Identifier">
							<C-0065 description="Message Type Identifier">
								<xsl:value-of select="*:UNH/*:messageIdentifier/*:id"/>
							</C-0065>
							<C-0052 description="Message type version number">
								<xsl:value-of select="*:UNH/*:messageIdentifier/*:versionNum"/>
							</C-0052>
							<C-0054 description="Message type release number">
								<xsl:value-of select="*:UNH/*:messageIdentifier/*:releaseNum"/>
							</C-0054>
							<C-0051 description="Controlling agency">
								<xsl:value-of select="*:UNH/*:messageIdentifier/*:controllingAgencyCode"/>
							</C-0051>
						</E-S009>
						<E-0068 description="Common access reference">
							<xsl:value-of select="*:UNH/*:commonAccessRef"/>
						</E-0068>
						<E-S010 description="Status of the transfer">
							<C-0070 description="Sequence of transfers">
								<xsl:value-of select="*:UNH/*:transferStatus/*:sequence"/>
							</C-0070>
						</E-S010>
					</UNH>
					<xsl:copy-of copy-namespaces="no" select="*[local-name() = $root]/*"/>
				</Group0>
				<UNT>
					<E-0074 description="NUMBER OF SEGMENTS IN A MESSAGE">
						<xsl:value-of select="*:UNT/*:segmentCount"/>
					</E-0074>
					<E-0062 description="MESSAGE REFERENCE NUMBER">
						<xsl:value-of select="*:UNT/*:messageRefNum"/>
					</E-0062>
				</UNT>
			</xsl:for-each>
		</MESSAGE>
	</xsl:element>
</xsl:template>

</xsl:stylesheet>
