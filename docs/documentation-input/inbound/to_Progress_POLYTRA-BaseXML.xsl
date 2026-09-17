<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:fo="http://www.w3.org/1999/XSL/Format" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:fn="http://www.w3.org/2005/xpath-functions">
	<xsl:output method="xml" indent="yes" encoding="UTF-8" standalone="yes" omit-xml-declaration="no"/>
	<xsl:template name="formatDate">
		<xsl:param name="date"/>
		<xsl:value-of select="concat(substring($date,7,2),'/',substring($date,5,2),'/',substring($date,1,4))"/>
	</xsl:template>
	<xsl:template name="getNodeValues">
		<xsl:for-each select="descendant::text()">
			<xsl:value-of select="concat(self::text(),'|')"/>
		</xsl:for-each>
	</xsl:template>
	<xsl:template name="getNodeValuesNADN1">
		<xsl:for-each select="descendant::text()[not(ancestor-or-self::E-C082 or ancestor-or-self::C-3124)]">
			<xsl:value-of select="concat(self::text(),'|')"/>
		</xsl:for-each>
	</xsl:template>
	<xsl:variable name="contrCarriage">
		<Value id="29">Pier-to-door</Value>
		<Value id="28">Door-to pier</Value>
		<Value id="27">Door-to-door</Value>
		<Value id="30">Pier-to pier</Value>
	</xsl:variable>
	<xsl:variable name="beladeart">
		<Value id="1">Conventional</Value>
		<Value id="2">LCL/LCL</Value>
		<Value id="3">FCL/FCL</Value>
		<Value id="4">FCL/LCL</Value>
		<Value id="5">LCL/FCL</Value>
	</xsl:variable>
	<xsl:template match="/">
		<Messages>
			<xsl:for-each select="IFTMIN/MESSAGE/Group0">
				<xsl:sort select="BGM/E-C106/C-1004" order="ascending"/>
				<xsl:sort select="UNH/E-0068" order="ascending"/>
				<xsl:variable name="HL" select="BGM/E-C106/C-1004"/>
				<xsl:variable name="partload">
					<xsl:if test="/IFTMIN/MESSAGE/Group0[BGM/E-C106/C-1004=$HL and UNH/E-0068='BL00']">
						<xsl:value-of select="'no'"/>
					</xsl:if>
					<xsl:if test="not(/IFTMIN/MESSAGE/Group0[BGM/E-C106/C-1004=$HL and UNH/E-0068='BL00'])">
						<xsl:value-of select="'yes'"/>
					</xsl:if>
				</xsl:variable>
				<xsl:variable name="scenario">
					<xsl:choose>
						<xsl:when test="	FTX[E-4451='SIC']/E-C108/C-4440[contains(lower-case(.), 'house')] or 
											FTX[E-4451='SIC']/E-C108/C-4440[contains(lower-case(.), 'haus')] or 
											FTX[E-4451='SIC']/E-C108/C-4440[contains(lower-case(.), 'hause')] or 
											FTX[E-4451='AAS']/E-C108/C-4440[contains(lower-case(.), 'house')] or 
											FTX[E-4451='AAS']/E-C108/C-4440[contains(lower-case(.), 'haus')] or 
											FTX[E-4451='AAS']/E-C108/C-4440[contains(lower-case(.), 'hause')]">
							<xsl:choose>
								<xsl:when test="//NAD[E-3035='FW']/E-C082/C-3039 = '2683269' or //NAD[E-3035='FW']/E-C082/C-3039 = '5904903'">
									<xsl:text>72BASF HBL</xsl:text>
								</xsl:when>
								<xsl:when test="//NAD[E-3035='FW']/E-C082/C-3039 = '4953206'">
									<xsl:text>74BASF HBL</xsl:text>
								</xsl:when>
								<xsl:otherwise>
									<xsl:text>71BASF HBL</xsl:text>
								</xsl:otherwise>
							</xsl:choose>
						</xsl:when>
						<xsl:otherwise>
							<xsl:choose>
								<xsl:when test="//NAD[E-3035='FW']/E-C082/C-3039 = '2683269' or //NAD[E-3035='FW']/E-C082/C-3039 = '5904903'">
									<xsl:text>72BASF RBL</xsl:text>
								</xsl:when>
								<xsl:when test="//NAD[E-3035='FW']/E-C082/C-3039 = '4953206'">
									<xsl:text>74BASF RBL</xsl:text>
								</xsl:when>
								<xsl:otherwise>
									<xsl:text>71BASF RBL</xsl:text>
								</xsl:otherwise>
							</xsl:choose>
						</xsl:otherwise>
					</xsl:choose>
				</xsl:variable>
				<Message Type="BASF" NumericFormat="American" PreProcess="CFW24350.r" PostProcess="CFW24420.r">
					<MainFiles>
						<MainFile>
							<xsl:if test="$partload='no'">
								<xsl:call-template name="iftminSegment">
									<xsl:with-param name="scenario" select="''"/>
								</xsl:call-template>
							</xsl:if>
							<xsl:if test="$partload='yes'">
								<xsl:call-template name="iftminSegment_BL00"/>
								<SubFiles>
									<MainFile>
										<FileSubFile>Y</FileSubFile>
										<xsl:call-template name="iftminSegment">
											<xsl:with-param name="scenario" select="$scenario"/>
										</xsl:call-template>
									</MainFile>
								</SubFiles>
							</xsl:if>
						</MainFile>
					</MainFiles>
				</Message>
			</xsl:for-each>
		</Messages>
	</xsl:template>
	<xsl:template name="iftminSegment">
		<xsl:param name="scenario"/>
		<xsl:variable name="portOfDischarge">
			<xsl:value-of select="Group8/Group9/LOC[E-3227 = 12]/E-C517/C-3225"/>
		</xsl:variable>
		<xsl:variable name="portOfDischargeName">
			<xsl:value-of select="Group8/Group9/LOC[E-3227 = 12]/E-C517/C-3224"/>
		</xsl:variable>
		<xsl:variable name="portOfLoading">
			<xsl:value-of select="Group8/Group9/LOC[E-3227 = 5]/E-C517/C-3225"/>
		</xsl:variable>
		<xsl:variable name="portOfLoadingName">
			<xsl:value-of select="Group8/Group9/LOC[E-3227 = 5]/E-C517/C-3224"/>
		</xsl:variable>
		<xsl:variable name="PositionFile">
			<xsl:value-of select="position()"/>
		</xsl:variable>
		<SearchFields>
			<SearchField>REFCFL</SearchField>
			<SearchField>STFLFL</SearchField>
		</SearchFields>
		<FileTypeOfFile>OP</FileTypeOfFile>
		<xsl:for-each select="Group11/NAD[E-3035='CZ']">
			<FileThirdParty>
				<xsl:attribute name="ThirdPartyID" select="E-C082/C-3039"/>BASF</FileThirdParty>
		</xsl:for-each>
		<FileImportExport>E</FileImportExport>
		<xsl:if test="Group37">
			<FileStatus>OP</FileStatus>
		</xsl:if>
		<xsl:if test="not(Group37)">
			<xsl:choose>
				<xsl:when test="//NAD[E-3035='FW']/E-C082/C-3039 = '2683269'">
					<FileStatus>OP</FileStatus>
				</xsl:when>
				<xsl:when test="//NAD[E-3035='FW']/E-C082/C-3039 = '5904903'">
					<FileStatus>OP</FileStatus>
				</xsl:when>
				<xsl:otherwise>
					<FileStatus>TP</FileStatus>
					<FileTempFile>Y</FileTempFile>
				</xsl:otherwise>
			</xsl:choose>
		</xsl:if>
		<FileCustomerReference>
			<xsl:value-of select="BGM/E-C106/C-1004"/>
			<xsl:value-of select="UNH/E-0068"/>
		</FileCustomerReference>
		<xsl:if test="Group3/RFF[E-C506/C-1153 = 'BN']">
			<FileAgentReference>
				<xsl:value-of select="Group3/RFF/E-C506[C-1153 = 'BN']/C-1154"/>
			</FileAgentReference>
		</xsl:if>
		<xsl:for-each select="Group8/TDT[E-8051 = 20]/E-C220[C-8067 = 10]">
			<FileMainCarriage>
				<xsl:value-of select="../E-C222/C-8212"/>
			</FileMainCarriage>
		</xsl:for-each>
		<FileMainCarriageQualifier>VSSEL</FileMainCarriageQualifier>
		<xsl:for-each select="Group8/DTM/E-C507[C-2005 = 132]">
			<FileEts Format="DD/MM/YYYY">
				<xsl:call-template name="formatDate">
					<xsl:with-param name="date" select="C-2380"/>
				</xsl:call-template>
			</FileEts>
		</xsl:for-each>
		<xsl:for-each select="Group8/DTM/E-C507[C-2005 = 133]">
			<FileEtd Format="DD/MM/YYYY">
				<xsl:call-template name="formatDate">
					<xsl:with-param name="date" select="C-2380"/>
				</xsl:call-template>
			</FileEtd>
		</xsl:for-each>
		<xsl:if test="not($scenario='')">
			<FileScenario>
				<xsl:value-of select="$scenario"/>
			</FileScenario>
		</xsl:if>
		<xsl:if test="$scenario=''">
			<xsl:choose>
				<xsl:when test="Group18[1]/LOC[E-3227 = 1]/E-C517/C-3225 = 'FOB'">
					<xsl:choose>
						<xsl:when test="//NAD[E-3035='FW']/E-C082/C-3039 = '2683269'">
							<FileScenario>72BASF FOB</FileScenario>
						</xsl:when>
						<xsl:when test="//NAD[E-3035='FW']/E-C082/C-3039 = '5904903'">
							<FileScenario>72BASF FOB</FileScenario>
						</xsl:when>
						<xsl:when test="//NAD[E-3035='FW']/E-C082/C-3039 = '4953206'">
							<FileScenario>74BASF FOB</FileScenario>
						</xsl:when>
						<xsl:otherwise>
							<xsl:if test="Group37">
								<FileScenario>71BASF FOB FCL SND</FileScenario>
							</xsl:if>
							<xsl:if test="not(Group37)">
								<FileScenario>71BASF FOB LCL SND</FileScenario>
							</xsl:if>
						</xsl:otherwise>
					</xsl:choose>
				</xsl:when>
				<xsl:when test="Group18[1]/LOC[E-3227 = 1]/E-C517/C-3225 = 'FCA'">
					<xsl:choose>
						<xsl:when test="//NAD[E-3035='FW']/E-C082/C-3039 = '2683269'">
							<FileScenario>72BASF FOB</FileScenario>
						</xsl:when>
						<xsl:when test="//NAD[E-3035='FW']/E-C082/C-3039 = '5904903'">
							<FileScenario>72BASF FOB</FileScenario>
						</xsl:when>
						<xsl:when test="//NAD[E-3035='FW']/E-C082/C-3039 = '4953206'">
							<FileScenario>74BASF FOB</FileScenario>
						</xsl:when>
						<xsl:otherwise>
							<xsl:if test="Group37">
								<FileScenario>71BASF FCA FCL SND</FileScenario>
							</xsl:if>
							<xsl:if test="not(Group37)">
								<FileScenario>71BASF FCA LCL SND</FileScenario>
							</xsl:if>
						</xsl:otherwise>
					</xsl:choose>
				</xsl:when>
				<xsl:when test="Group18[1]/LOC[E-3227 = 1]/E-C517/C-3225 = 'EXW'">
					<xsl:choose>
						<xsl:when test="//NAD[E-3035='FW']/E-C082/C-3039 = '2683269'">
							<FileScenario>72BASF FOB</FileScenario>
						</xsl:when>
						<xsl:when test="//NAD[E-3035='FW']/E-C082/C-3039 = '5904903'">
							<FileScenario>72BASF FOB</FileScenario>
						</xsl:when>
						<xsl:when test="//NAD[E-3035='FW']/E-C082/C-3039 = '4953206'">
							<FileScenario>74BASF FOB</FileScenario>
						</xsl:when>
						<xsl:otherwise>
							<xsl:if test="Group37">
								<FileScenario>71BASF EXW FCL SND</FileScenario>
							</xsl:if>
							<xsl:if test="not(Group37)">
								<FileScenario>71BASF EXW LCL SND</FileScenario>
							</xsl:if>
						</xsl:otherwise>
					</xsl:choose>
				</xsl:when>
				<xsl:when test="Group18[1]/LOC[E-3227 = 1]/E-C517/C-3225 = 'FAS'">
					<xsl:choose>
						<xsl:when test="//NAD[E-3035='FW']/E-C082/C-3039 = '2683269'">
							<FileScenario>72BASF FOB</FileScenario>
						</xsl:when>
						<xsl:when test="//NAD[E-3035='FW']/E-C082/C-3039 = '5904903'">
							<FileScenario>72BASF FOB</FileScenario>
						</xsl:when>
						<xsl:when test="//NAD[E-3035='FW']/E-C082/C-3039 = '4953206'">
							<FileScenario>74BASF FOB</FileScenario>
						</xsl:when>
						<xsl:otherwise>
							<xsl:if test="Group37">
								<FileScenario>71BASF FAS FCL SND</FileScenario>
							</xsl:if>
							<xsl:if test="not(Group37)">
								<FileScenario>71BASF FAS LCL SND</FileScenario>
							</xsl:if>
						</xsl:otherwise>
					</xsl:choose>
				</xsl:when>
				<xsl:otherwise>
					<xsl:if test="Group37">
						<xsl:choose>
							<xsl:when test="//NAD[E-3035='FW']/E-C082/C-3039 = '2683269'">
								<FileScenario>72BASF FCL</FileScenario>
							</xsl:when>
							<xsl:when test="//NAD[E-3035='FW']/E-C082/C-3039 = '5904903'">
								<FileScenario>72BASF FCL</FileScenario>
							</xsl:when>
							<xsl:when test="//NAD[E-3035='FW']/E-C082/C-3039 = '4953206'">
								<FileScenario>74BASF FCL</FileScenario>
							</xsl:when>
							<xsl:otherwise>
								<FileScenario>71BASF FCL</FileScenario>
							</xsl:otherwise>
						</xsl:choose>
					</xsl:if>
					<xsl:if test="not(Group37)">
						<xsl:choose>
							<xsl:when test="//NAD[E-3035='FW']/E-C082/C-3039 = '2683269'">
								<FileScenario>72BASF LCL</FileScenario>
							</xsl:when>
							<xsl:when test="//NAD[E-3035='FW']/E-C082/C-3039 = '5904903'">
								<FileScenario>72BASF LCL</FileScenario>
							</xsl:when>
							<xsl:when test="//NAD[E-3035='FW']/E-C082/C-3039 = '4953206'">
								<FileScenario>74BASF LCL</FileScenario>
							</xsl:when>
							<xsl:when test="$portOfLoading = 'DEHAM'">
								<FileScenario>70BASF LCL</FileScenario>
							</xsl:when>
							<xsl:when test="$portOfLoading = 'DEBRV'">
								<FileScenario>70BASF LCL</FileScenario>
							</xsl:when>
							<xsl:otherwise>
								<FileScenario>71BASF LCL</FileScenario>
							</xsl:otherwise>
						</xsl:choose>
					</xsl:if>
				</xsl:otherwise>
			</xsl:choose>
		</xsl:if>
		<FileCompany>
			<xsl:if test="//NAD[E-3035='FW']/E-C082/C-3039 = '2683269' or //NAD[E-3035='FW']/E-C082/C-3039 = '5904903'">FPLES</xsl:if>
			<xsl:if test="//NAD[E-3035='FW']/E-C082/C-3039 = '4953206'">FRACHTITA</xsl:if>
			<xsl:if test="$portOfLoading = 'DEHAM'">POLYTRA</xsl:if>
			<xsl:if test="$portOfLoading = 'DEBRV'">POLYTRA</xsl:if>
		</FileCompany>
		<FileGroup>
			<xsl:if test="//NAD[E-3035='FW']/E-C082/C-3039 = '2683269' or //NAD[E-3035='FW']/E-C082/C-3039 = '5904903'">BASFES</xsl:if>
			<xsl:if test="//NAD[E-3035='FW']/E-C082/C-3039 = '4953206'">01</xsl:if>
			<xsl:if test="$portOfLoading = 'DEHAM'">BASFHA</xsl:if>
			<xsl:if test="$portOfLoading = 'DEBRV'">BASFHA</xsl:if>
		</FileGroup>
		<FileDepartment>
			<xsl:if test="//NAD[E-3035='FW']/E-C082/C-3039 = '2683269' or //NAD[E-3035='FW']/E-C082/C-3039 = '5904903'">72</xsl:if>
			<xsl:if test="//NAD[E-3035='FW']/E-C082/C-3039 = '4953206'">74</xsl:if>
			<xsl:if test="$portOfLoading = 'DEHAM'">70</xsl:if>
			<xsl:if test="$portOfLoading = 'DEBRV'">70</xsl:if>
		</FileDepartment>
		<FileUser/>
		<FileContactName/>
		<xsl:if test="$scenario = '71BASF HBL'">
			<!-- subdossiers van '71BASF HBL' (oftewel met status 'MB') moeten een specifieke transporteur krijgen -->
			<FileTransportCompany>
				<xsl:text>MBSUB_CA</xsl:text>
			</FileTransportCompany>
		</xsl:if>
		<xsl:if test="not($scenario = '71BASF HBL')">
			<xsl:for-each select="Group11/NAD[E-3035 = 'CA']">
				<FileTransportCompany>
					<xsl:value-of select="concat(E-C082/C-3039,'_CA')"/>
				</FileTransportCompany>
			</xsl:for-each>
		</xsl:if>
		<FilePortOfLoading>
			<xsl:value-of select="$portOfLoading"/>
		</FilePortOfLoading>
		<FilePortOfLoadingName>
			<xsl:value-of select="$portOfLoadingName"/>
		</FilePortOfLoadingName>
		<FilePortOfDischarge>
			<xsl:value-of select="$portOfDischarge"/>
		</FilePortOfDischarge>
		<FilePortOfDischargeName>
			<xsl:value-of select="$portOfDischargeName"/>
		</FilePortOfDischargeName>
		<xsl:for-each select="Group18/LOC[E-3227 = 1][1]">
			<FileFinalDestination>
				<xsl:value-of select="E-C517/C-3224"/>
			</FileFinalDestination>
		</xsl:for-each>
		<xsl:for-each select="Group18/LOC[E-3227 = 1][1]">
			<FileTermsOfDelivery Delimiter="|">
				<xsl:value-of select="E-C517/C-3225"/>
				<!--
				<xsl:choose>
					<xsl:when test="E-C517/C-3225 = 'FCA'">FOB</xsl:when>
					<xsl:otherwise><xsl:value-of select="E-C517/C-3225"/></xsl:otherwise>
				</xsl:choose>
			-->
			</FileTermsOfDelivery>
		</xsl:for-each>
		<FileReserveFields>
			<xsl:for-each select="Group8/Group9/LOC[E-3227 = 12]">
				<ReserveField4>
					<xsl:value-of select="substring(E-C517/C-3225, 1, 2)"/>
				</ReserveField4>
			</xsl:for-each>
		</FileReserveFields>
		<FileUdf>
			<xsl:for-each select="Group8/TDT[E-8051 = 20]/E-C220[C-8067 = 10]">
				<Udf>
					<UdfCode CreateIfNotExists="Y">NEW-LLOYD</UdfCode>
					<UdfValue>
						<xsl:value-of select="../E-C222/C-8213"/>
					</UdfValue>
				</Udf>
			</xsl:for-each>
			<xsl:for-each select="Group8/TDT[E-8051 = 20]">
				<Udf>
					<UdfCode CreateIfNotExists="Y">VOYNBR</UdfCode>
					<UdfValue>
						<xsl:value-of select="E-8028"/>
					</UdfValue>
				</Udf>
			</xsl:for-each>
			<Udf>
				<UdfCode CreateIfNotExists="Y">Place-TOD</UdfCode>
				<UdfValue>
					<xsl:value-of select="Group18[1]/LOC[E-3227 = 1][1]/E-C517[1]/C-3224[1]"/>
				</UdfValue>
			</Udf>
			<Udf>
				<UdfCode CreateIfNotExists="Y">Place-TOD20</UdfCode>
				<UdfValue>
					<xsl:value-of select="Group8/Group9/LOC[E-3227 = 20][1]/E-C517[1]/C-3225[1]"/>
				</UdfValue>
			</Udf>
			<xsl:for-each select="CTA[E-3139='MS']">
				<Udf>
					<UdfCode CreateIfNotExists="Y">Sped-CTA</UdfCode>
					<UdfValue>
						<xsl:value-of select="E-C056/C-3412"/>
					</UdfValue>
				</Udf>
			</xsl:for-each>
			<xsl:for-each select="COM/E-C076[C-3155='TE']">
				<Udf>
					<UdfCode CreateIfNotExists="Y">Sped-TEL</UdfCode>
					<UdfValue>
						<xsl:value-of select="C-3148"/>
					</UdfValue>
				</Udf>
			</xsl:for-each>
			<xsl:for-each select="COM/E-C076[C-3155='FX']">
				<Udf>
					<UdfCode CreateIfNotExists="Y">Sped-FAX</UdfCode>
					<UdfValue>
						<xsl:value-of select="C-3148"/>
					</UdfValue>
				</Udf>
			</xsl:for-each>
			<xsl:for-each select="COM/E-C076[C-3155='EM']">
				<Udf>
					<UdfCode CreateIfNotExists="Y">Sped-EMAIL</UdfCode>
					<UdfValue>
						<xsl:value-of select="C-3148"/>
					</UdfValue>
				</Udf>
			</xsl:for-each>
			<Udf>
				<UdfCode>MessageFunction</UdfCode>
				<UdfValue>
					<xsl:value-of select="BGM/E-1225"/>
				</UdfValue>
			</Udf>
			<Udf>
				<UdfCode CreateIfNotExists="Y">MesFu</UdfCode>
				<UdfValue>
					<xsl:value-of select="BGM/E-1225"/>
				</UdfValue>
			</Udf>
			<xsl:for-each select="Group8/Group9/LOC[E-3227 = 13]">
				<Udf>
					<UdfCode CreateIfNotExists="Y">PLCOFTRNSSHPM</UdfCode>
					<UdfValue>
						<xsl:value-of select="E-C519/C-3223"/>
					</UdfValue>
				</Udf>
			</xsl:for-each>
			<!-- Alle FTX-segmenten <Udf> -->
			<xsl:for-each-group select="descendant::FTX[not(ancestor-or-self::Group18)]" group-by="E-4451">
				<Udf>
					<UdfCode CreateIfNotExists="Y">
						<xsl:text>FTX-</xsl:text>
						<xsl:value-of select="current-grouping-key()"/>
					</UdfCode>
					<UdfValue>
						<!-- TRFS 28/03/2012 
								 -> Add the value of BGM segment in the FTX-ABO segment.
								    If this isn't done, the KPI's and containers aren't processed correctly! -->
						<xsl:if test="current-grouping-key()='ABO'">
							<xsl:value-of select="/IFTMIN/MESSAGE/Group0/BGM/E-C002/C-1000"/>
							<xsl:text> &#xD; </xsl:text>
						</xsl:if>
						<xsl:for-each select="current-group()/E-C108/C-4440">
							<xsl:value-of select="."/>
						</xsl:for-each>
					</UdfValue>
				</Udf>
			</xsl:for-each-group>
			<xsl:for-each-group select="Group3/RFF | Group8/Group10/RFF | Group11/Group15/RFF | Group11/Group16/RFF | Group11/Group17/RFF | Group37/RFF" group-by="E-C506/C-1153">
				<Udf>
					<UdfCode CreateIfNotExists="Y">
						<xsl:text>RFF-</xsl:text>
						<xsl:value-of select="current-grouping-key()"/>
					</UdfCode>
					<UdfValue>
						<xsl:value-of select="fn:string-join(current-group()/E-C506/C-1154, ';')"/>
					</UdfValue>
				</Udf>
				<xsl:if test="current-grouping-key() = 'LI'">
					<Udf>
						<UdfCode CreateIfNotExists="Y">
							<xsl:text>RFF-LI2</xsl:text>
						</UdfCode>
						<UdfValue>
							<xsl:value-of select="fn:string-join(current-group()/E-C506/C-1156, ';')"/>
						</UdfValue>
					</Udf>
				</xsl:if>
			</xsl:for-each-group>
			<Udf>
				<UdfCode CreateIfNotExists="Y">
					<xsl:text>UNH</xsl:text>
				</UdfCode>
				<UdfValue>
					<xsl:value-of select="UNH/E-0068"/>
				</UdfValue>
			</Udf>
			<Udf>
				<UdfCode CreateIfNotExists="Y">TMD</UdfCode>
				<UdfValue>
					<xsl:value-of select="Group37[1]/TMD/E-C219/C-8334"/>
				</UdfValue>
			</Udf>
			<xsl:for-each select="Group8/TSR/E-C536/C-4065">
				<xsl:if test="position() = 1">
					<xsl:variable name="tempContrCarriage">
						<xsl:value-of select="./text()"/>
					</xsl:variable>
					<Udf>
						<UdfCode CreateIfNotExists="Y">ContrCarriage-code</UdfCode>
						<UdfValue>
							<xsl:value-of select="$tempContrCarriage"/>
						</UdfValue>
					</Udf>
					<Udf>
						<UdfCode CreateIfNotExists="Y">ContrCarriage-desc</UdfCode>
						<UdfValue>
							<xsl:value-of select="$contrCarriage/Value[@id = $tempContrCarriage]"/>
						</UdfValue>
					</Udf>
				</xsl:if>
			</xsl:for-each>
			<xsl:for-each select="Group37/TMD/E-C219/C-8335">
				<xsl:if test="position() = 1">
					<xsl:variable name="tempBeladeart">
						<xsl:value-of select="./text()"/>
					</xsl:variable>
					<Udf>
						<UdfCode CreateIfNotExists="Y">Beladeart-code</UdfCode>
						<UdfValue>
							<xsl:value-of select="$tempBeladeart"/>
						</UdfValue>
					</Udf>
					<Udf>
						<UdfCode CreateIfNotExists="Y">Beladeart-desc</UdfCode>
						<UdfValue>
							<xsl:value-of select="replace($beladeart/Value[@id = $tempBeladeart],'/','')"/>
						</UdfValue>
					</Udf>
				</xsl:if>
			</xsl:for-each>
			<Udf>
				<UdfCode CreateIfNotExists="Y">UNB_DT</UdfCode>
				<UdfValue>
					<xsl:value-of select="../UNB/E-S004/C-0017"/>
					<xsl:text>-</xsl:text>
					<xsl:value-of select="../UNB/E-S004/C-0019"/>
				</UdfValue>
			</Udf>
			<Udf>
				<UdfCode CreateIfNotExists="Y">UNH_NR</UdfCode>
				<UdfValue>
					<xsl:value-of select="UNH/E-0062"/>
				</UdfValue>
			</Udf>
		</FileUdf>
		<FileParties DeletePrevious="Y">
			<xsl:if test="$scenario = '71BASF HBL'">
				<!-- subdossiers van '71BASF HBL' (oftewel met status 'MB', moeten een specifieke transporteur krijgen -->
				<Party>
					<xsl:attribute name="Type">
						<xsl:value-of select="'CA'"/>
					</xsl:attribute>
					<PartyId>
						<xsl:text>MBSUB_CA</xsl:text>
					</PartyId>
				</Party>
				<Party>
					<xsl:attribute name="Type">
						<xsl:value-of select="'AG'"/>
					</xsl:attribute>
					<PartyId>
						<xsl:text>MBSUB_AG</xsl:text>
					</PartyId>
				</Party>
				<!-- alle partijen behalve CA oplijsten -->
				<xsl:for-each select="Group11/NAD[E-3035 != 'CA']">
					<xsl:call-template name="printAddress">
						<xsl:with-param name="country" select="$portOfDischarge"/>
					</xsl:call-template>
				</xsl:for-each>
			</xsl:if>
			<xsl:if test="not($scenario = '71BASF HBL')">
				<!-- in het andere geval alle parijen overlopen -->
				<xsl:for-each select="Group11/NAD">
					<xsl:call-template name="printAddress">
						<xsl:with-param name="country" select="$portOfDischarge"/>
					</xsl:call-template>
				</xsl:for-each>
			</xsl:if>
			<xsl:for-each select="Group18/Group19/NAD">
				<xsl:call-template name="printAddress">
					<xsl:with-param name="country" select="$portOfDischarge"/>
				</xsl:call-template>
			</xsl:for-each>
			<xsl:for-each select="Group37/Group39/NAD">
				<xsl:call-template name="printAddress">
					<xsl:with-param name="country" select="$portOfDischarge"/>
				</xsl:call-template>
			</xsl:for-each>
		</FileParties>
		<xsl:variable name="containers">
			<Containers>
				<xsl:for-each select="Group37">
					<Container>
						<ID>
							<xsl:value-of select="concat($PositionFile, position())"/>
						</ID>
						<ContContainerNumber>
							<xsl:value-of select="EQD/E-C237/C-8260"/>
						</ContContainerNumber>
					</Container>
				</xsl:for-each>
			</Containers>
		</xsl:variable>
		<FileGoodLines DeletePrevious="Y">
			<xsl:for-each select="Group18">
				<GoodLine>
					<ID>
						<xsl:value-of select="concat($PositionFile, position())"/>
					</ID>
					<xsl:variable name="unitvar">
						<xsl:choose>
							<xsl:when test="GID/E-C213[2]/C-7065[1] != ''">
								<xsl:value-of select="GID/E-C213[2]/C-7065[1]"/>
							</xsl:when>
							<xsl:otherwise>
								<xsl:value-of select="GID/E-C213[1]/C-7065[1]"/>
							</xsl:otherwise>
						</xsl:choose>
					</xsl:variable>
					<!-- check SAP-number (starting with 300) to fill the Goodreference -->
					<xsl:variable name="threehundred">
						<!-- SPARTAAA!!!! -->
						<xsl:value-of select="Group22/RFF/E-C506[C-1153 = 'VN']/C-1154"/>
					</xsl:variable>
					<xsl:if test="$threehundred != ''">
						<GoodReference Qualifier="FLN">
							<xsl:value-of select="$threehundred"/>
						</GoodReference>
					</xsl:if>
					<GoodStatisticalCode>
						<xsl:value-of select="Group22/RFF/E-C506[C-1153 = 'AQV']/C-1154"/>
					</GoodStatisticalCode>
					<GoodNumberOfPieces Unit="{$unitvar}">
						<xsl:choose>
							<xsl:when test="$unitvar = GID/E-C213[2]/C-7065[1]">
								<xsl:value-of select="GID/E-C213[2]/C-7224[1]"/>
							</xsl:when>
							<xsl:otherwise>
								<xsl:value-of select="GID/E-C213[1]/C-7224[1]"/>
							</xsl:otherwise>
						</xsl:choose>
					</GoodNumberOfPieces>
					<GoodGrossWeight>
						<xsl:choose>
							<xsl:when test="Group20/MEA[E-6311 = 'WT'][E-C502/C-6313 = 'WT']/E-C174/C-6314">
								<xsl:value-of select="( Group20/MEA[E-6311 = 'WT'][E-C502/C-6313 = 'AAE']/E-C174/C-6314 + Group20/MEA[E-6311 = 'WT'][E-C502/C-6313 = 'WT']/E-C174/C-6314 )"/>
							</xsl:when>
							<xsl:otherwise>
								<xsl:value-of select="( Group20/MEA[E-6311 = 'WT'][E-C502/C-6313 = 'AAE']/E-C174/C-6314 )"/>
							</xsl:otherwise>
						</xsl:choose>
					</GoodGrossWeight>
					<xsl:for-each select="Group20/MEA">
						<xsl:if test="E-6311 = 'WT'">
							<xsl:if test="E-C502/C-6313 = 'AAC'">
								<GoodNettWeight>
									<xsl:value-of select="E-C174/C-6314"/>
								</GoodNettWeight>
							</xsl:if>
						</xsl:if>
						<xsl:if test="E-6311 = 'VOL'">
							<xsl:if test="E-C502/C-6313 = 'ABJ'">
								<GoodVolume>
									<xsl:value-of select="E-C174/C-6314"/>
								</GoodVolume>
							</xsl:if>
						</xsl:if>
					</xsl:for-each>
					<xsl:for-each select="Group22/RFF">
						<xsl:if test="E-C506/C-1153 = 'LI'">
							<GoodCustomerReference>
								<xsl:value-of select="E-C506/C-1154"/>
								<xsl:text>-</xsl:text>
								<xsl:value-of select="E-C506/C-1156"/>
							</GoodCustomerReference>
						</xsl:if>
					</xsl:for-each>
					<GoodUdf>
						<Udf>
							<UdfCode CreateIfNotExists="Y">Packing1</UdfCode>
							<UdfValue>
								<xsl:value-of select="GID/E-C213[1]/C-7065[1]"/>
							</UdfValue>
						</Udf>
						<Udf>
							<UdfCode CreateIfNotExists="Y">Packing2</UdfCode>
							<UdfValue>
								<xsl:value-of select="GID/E-C213[2]/C-7065[1]"/>
							</UdfValue>
						</Udf>
						<xsl:for-each select="Group22/RFF">
							<xsl:if test="E-C506/C-1153 = 'OP'">
								<xsl:choose>
									<xsl:when test="E-C506/C-1154 = '.'"/>
									<xsl:when test="not(E-C506/C-1154)"/>
									<xsl:otherwise>
										<Udf>
											<UdfCode CreateIfNotExists="Y">BUYORDNR</UdfCode>
											<UdfValue>
												<xsl:value-of select="concat('P.O. NBR ',E-C506/C-1154)"/>
											</UdfValue>
										</Udf>
									</xsl:otherwise>
								</xsl:choose>
							</xsl:if>
							<xsl:if test="E-C506/C-1153 = 'AQV'">
								<Udf>
									<UdfCode CreateIfNotExists="Y">COMMODITYG</UdfCode>
									<UdfValue>
										<xsl:value-of select="E-C506/C-1154"/>
									</UdfValue>
								</Udf>
							</xsl:if>
							<xsl:if test="E-C506/C-1153 = 'ABT'">
								<Udf>
									<UdfCode CreateIfNotExists="Y">ACID</UdfCode>
									<UdfValue>
										<xsl:value-of select="E-C506/C-1154"/>
									</UdfValue>
								</Udf>
							</xsl:if>
							<xsl:if test="E-C506/C-1153 = 'AKD'">
								<Udf>
									<UdfCode CreateIfNotExists="Y">SRVYREFNR</UdfCode>
									<UdfValue>
										<xsl:value-of select="E-C506/C-1154"/>
									</UdfValue>
								</Udf>
							</xsl:if>
							<xsl:if test="E-C506/C-1153 = 'IP'">
								<Udf>
									<UdfCode CreateIfNotExists="Y">IMPLICNR</UdfCode>
									<UdfValue>
										<xsl:value-of select="E-C506/C-1154"/>
									</UdfValue>
								</Udf>
							</xsl:if>
							<xsl:if test="E-C506/C-1153 = 'LC'">
								<Udf>
									<UdfCode CreateIfNotExists="Y">LOCNR</UdfCode>
									<UdfValue>
										<xsl:value-of select="E-C506/C-1154"/>
									</UdfValue>
								</Udf>
							</xsl:if>
						</xsl:for-each>
						<Udf>
							<UdfCode CreateIfNotExists="Y">ARTNR</UdfCode>
							<UdfValue>
								<xsl:value-of select="PIA/E-C212[1]/C-7140[1]"/>
							</UdfValue>
						</Udf>
						<Udf>
							<UdfCode CreateIfNotExists="Y">GTIN</UdfCode>
							<UdfValue>
								<xsl:value-of select="PIA/E-C212[2]/C-7140[1]"/>
							</UdfValue>
						</Udf>
						<!-- SHINCA -->
						<xsl:for-each select="FTX">
							<xsl:if test="E-4451 = 'SIC'">
								<Udf>
									<UdfCode CreateIfNotExists="Y">SHINCA</UdfCode>
									<UdfValue>
										<xsl:for-each select="E-C108/C-4440">
											<xsl:value-of select="."/>
										</xsl:for-each>
									</UdfValue>
								</Udf>
							</xsl:if>
						</xsl:for-each>
						<!-- FTX-AAC2 -->
						<xsl:for-each select="Group32/FTX">
							<xsl:if test="E-4451 = 'AAC' and E-C107/C-4441">
								<Udf>
									<UdfCode CreateIfNotExists="Y">FTX-AAC2</UdfCode>
									<UdfValue>
										<xsl:for-each select="E-C108/C-4440">
											<xsl:value-of select="."/>
										</xsl:for-each>
									</UdfValue>
								</Udf>
							</xsl:if>
						</xsl:for-each>
						<!-- Alle FTX-segmenten <Udf> -->
						<xsl:for-each-group select="descendant::FTX" group-by="E-4451">
							<Udf>
								<UdfCode CreateIfNotExists="Y">
									<xsl:text>FTX-</xsl:text>
									<xsl:value-of select="current-grouping-key()"/>
								</UdfCode>
								<UdfValue>
									<xsl:for-each select="current-group()/E-C108/C-4440">
										<xsl:if test="not(../../E-C107/C-4441)">
											<xsl:value-of select="."/>
											<xsl:text> &#xD; </xsl:text>
										</xsl:if>
									</xsl:for-each>
								</UdfValue>
							</Udf>
						</xsl:for-each-group>
						<Udf>
							<UdfCode CreateIfNotExists="Y">GIDnrPackages1</UdfCode>
							<UdfValue>
								<xsl:value-of select="GID/E-C213[1]/C-7224[1]"/>
							</UdfValue>
						</Udf>
						<Udf>
							<UdfCode CreateIfNotExists="Y">GIDnrPackages2</UdfCode>
							<UdfValue>
								<xsl:value-of select="GID/E-C213[2]/C-7224[1]"/>
							</UdfValue>
						</Udf>
						<Udf>
							<UdfCode CreateIfNotExists="Y">GIDnrPackages3</UdfCode>
							<UdfValue>
								<xsl:value-of select="GID/E-C213[3]/C-7224[1]"/>
							</UdfValue>
						</Udf>
						<Udf>
							<UdfCode CreateIfNotExists="Y">GIDrespAgency1</UdfCode>
							<UdfValue>
								<xsl:value-of select="GID/E-C213[1]/C-7064[1]"/>
							</UdfValue>
						</Udf>
						<Udf>
							<UdfCode CreateIfNotExists="Y">GIDrespAgency2</UdfCode>
							<UdfValue>
								<xsl:value-of select="GID/E-C213[2]/C-7064[1]"/>
							</UdfValue>
						</Udf>
						<Udf>
							<UdfCode CreateIfNotExists="Y">GIDrespAgency3</UdfCode>
							<UdfValue>
								<xsl:value-of select="GID/E-C213[3]/C-7064[1]"/>
							</UdfValue>
						</Udf>
						<!-- Alle FTX-segmenten <Udf> -->
						<xsl:for-each-group select=".//RFF" group-by="E-C506/C-1153">
							<Udf>
								<UdfCode CreateIfNotExists="Y">
									<xsl:text>RFF-</xsl:text>
									<xsl:value-of select="current-grouping-key()"/>
								</UdfCode>
								<UdfValue>
									<xsl:value-of select="string-join(current-group()/E-C506/C-1154, ';')"/>
								</UdfValue>
							</Udf>
							<xsl:if test="current-grouping-key() = 'LI'">
								<Udf>
									<UdfCode CreateIfNotExists="Y">
										<xsl:text>RFF-LI2</xsl:text>
									</UdfCode>
									<UdfValue>
										<xsl:value-of select="fn:string-join(current-group()/E-C506/C-1156, ';')"/>
									</UdfValue>
								</Udf>
							</xsl:if>
							<xsl:if test="current-grouping-key() = 'AHA'">
								<Udf>
									<UdfCode CreateIfNotExists="Y">
										<xsl:text>RFF-AHA2</xsl:text>
									</UdfCode>
									<UdfValue>
										<xsl:value-of select="fn:string-join(current-group()/E-C506/C-1156, ';')"/>
									</UdfValue>
								</Udf>
							</xsl:if>
						</xsl:for-each-group>
						<Udf>
							<UdfCode CreateIfNotExists="Y">MEA-WT-WT</UdfCode>
							<UdfValue>
								<xsl:value-of select="Group20/MEA[E-6311 = 'WT'][E-C502/C-6313 = 'WT']/E-C174/C-6314"/>
							</UdfValue>
						</Udf>
						<Udf>
							<UdfCode CreateIfNotExists="Y">MEA-WT-AAE</UdfCode>
							<UdfValue>
								<xsl:value-of select="Group20/MEA[E-6311 = 'WT'][E-C502/C-6313 = 'AAE']/E-C174/C-6314"/>
							</UdfValue>
						</Udf>
					</GoodUdf>
					<GoodMarksAndNumbers>
						<xsl:for-each select="Group23/PCI">
							<xsl:for-each select="E-C210/C-7102">
								<MarksAndNumbers>
									<MarksMarkAndNumber>
										<xsl:value-of select="."/>
									</MarksMarkAndNumber>
									<MarksDescription/>
								</MarksAndNumbers>
							</xsl:for-each>
						</xsl:for-each>
					</GoodMarksAndNumbers>
					<xsl:if test="Group32 and Group32/DGS/E-8273/text() != 'ZZZ'">
						<GoodDangerousGoodsNotifications>
							<DangerousGoodsNotification>
								<ImoImdgClass>
									<xsl:value-of select="Group32/DGS/E-C205/C-8351"/>
								</ImoImdgClass>
								<xsl:variable name="PSN">
									<xsl:for-each select="Group32/FTX[E-4451='AAC']/E-C108/C-4440">
										<xsl:if test="not(../../E-C107/C-4441)">
											<xsl:value-of select="."/>
										</xsl:if>
									</xsl:for-each>
								</xsl:variable>
								<ImoProperShippingName>
									<xsl:value-of select="substring($PSN, 1, 100)"/>
								</ImoProperShippingName>
								<xsl:if test="string-length($PSN) &gt; 80">
									<ImoRemarks>
										<Remark>
											<RemarkDetails>
												<Detail>
													<DetailInstruction>
														<xsl:value-of select="substring($PSN, 100)"/>
													</DetailInstruction>
												</Detail>
											</RemarkDetails>
										</Remark>
									</ImoRemarks>
								</xsl:if>
								<ImoTremCard>
									<xsl:value-of select="Group32/DGS/E-8273"/>
								</ImoTremCard>
								<ImoUnNumber>
									<xsl:value-of select="Group32/DGS/E-C234/C-7124"/>
								</ImoUnNumber>
								<ImoFlashpointActual>
									<xsl:choose>
										<xsl:when test="contains(Group32/DGS/E-C223/C-7106, '.')">
											<xsl:value-of select="substring-before(Group32/DGS/E-C223/C-7106, '.')"/>
										</xsl:when>
										<xsl:when test="contains(Group32/DGS/E-C223/C-7106, ',')">
											<xsl:value-of select="substring-before(Group32/DGS/E-C223/C-7106, ',')"/>
										</xsl:when>
										<xsl:otherwise>
											<xsl:value-of select="Group32/DGS/E-C223/C-7106"/>
										</xsl:otherwise>
									</xsl:choose>
								</ImoFlashpointActual>
								<ImoFlashpointActualQualifier>
									<xsl:value-of select="Group32/DGS/E-C223/C-6411"/>
								</ImoFlashpointActualQualifier>
								<ImoPackingGroup>
									<xsl:value-of select="Group32/DGS/E-8339"/>
								</ImoPackingGroup>
								<ImoEmsNumber>
									<xsl:value-of select="Group32/DGS/E-8364"/>
								</ImoEmsNumber>
								<ImoLabel1>
									<xsl:value-of select="Group32/DGS/E-C236/C-8246[2]"/>
								</ImoLabel1>
								<ImoRemarks>
									<Remark>
										<RemarkDetails>
											<xsl:for-each select="FTX[E-4451 = 'AAC']">
												<Detail>
													<DetailLineNumber>
														<xsl:value-of select="position()"/>
													</DetailLineNumber>
													<DetailInstruction>
														<xsl:value-of select="E-C108C-4440"/>
													</DetailInstruction>
												</Detail>
											</xsl:for-each>
										</RemarkDetails>
									</Remark>
								</ImoRemarks>
								<ImoFreeRemarks>
									<Remark>
										<RemarkDetails>
											<xsl:for-each select="FTX[E-4451 = 'AAD']">
												<Detail>
													<DetailLineNumber>
														<xsl:value-of select="position()"/>
													</DetailLineNumber>
													<DetailInstruction>
														<xsl:value-of select="E-C108/C-4440"/>
													</DetailInstruction>
												</Detail>
											</xsl:for-each>
										</RemarkDetails>
									</Remark>
								</ImoFreeRemarks>
							</DangerousGoodsNotification>
						</GoodDangerousGoodsNotifications>
					</xsl:if>
					<GoodRemarks>
						<xsl:for-each select="FTX">
							<Remark>
								<RemarkDetails>
									<xsl:for-each select="E-C108[1]/C-4440">
										<Detail>
											<DetailLineNumber>
												<xsl:value-of select="position()"/>
											</DetailLineNumber>
											<DetailInstruction>
												<xsl:value-of select="."/>
											</DetailInstruction>
										</Detail>
									</xsl:for-each>
								</RemarkDetails>
							</Remark>
						</xsl:for-each>
					</GoodRemarks>
					<GoodBillsOfLading>
						<BillOfLading>
							<BlNumber/>
							<BlReference/>
							<BlType>
								<xsl:for-each select="../Group11/Group13/DOC">
									<xsl:if test="position() = 1">
										<xsl:value-of select="E-C002/C-1001"/>
									</xsl:if>
								</xsl:for-each>
							</BlType>
							<xsl:choose>
								<xsl:when test="../Group8/Group9/LOC[E-3227 = 20]">
									<BlMovement>
										<xsl:text>16</xsl:text>
									</BlMovement>
									<BlOnCarriage Delimiter="|">
										<xsl:text>|</xsl:text>
										<xsl:text>|</xsl:text>
										<xsl:value-of select="../Group8/Group9/LOC[E-3227 = 20]/E-C517/C-3224"/>
									</BlOnCarriage>
								</xsl:when>
								<xsl:otherwise>
									<BlMovement>
										<xsl:text>15</xsl:text>
									</BlMovement>
									<!-- /* standaard OCEAN/OCEAN */ -->
								</xsl:otherwise>
							</xsl:choose>
							<BlDocumentCode/>
							<BlServiceContractNumber/>
							<BlVesselName>
								<xsl:for-each select="../Group8/TDT[E-8051 = 20]/E-C220[C-8067 = 10]">
									<xsl:value-of select="../E-C222/C-8212"/>
								</xsl:for-each>
							</BlVesselName>
							<BlPortOfLoading>
								<xsl:value-of select="$portOfLoading"/>
							</BlPortOfLoading>
							<BlPortOfDischarge>
								<xsl:value-of select="$portOfDischarge"/>
							</BlPortOfDischarge>
							<BlNumberOriginalBsL>
								<xsl:value-of select="sum(../Group11/Group13/DOC[E-C002/C-1001='705']/E-1218)"/>
							</BlNumberOriginalBsL>
							<BlFreightPayableAt/>
							<BlShippedDate/>
							<BlDateOfIssue/>
							<xsl:if test="LOC/E-3227 = '92'">
								<BlPlaceOfIssue>
									<xsl:value-of select="LOC/E-C519/C-3223"/>
								</BlPlaceOfIssue>
							</xsl:if>
							<xsl:for-each select="../Group11/NAD[E-3035='OS']">
								<BlShipper>
									<BlShipperPartyType>
										<xsl:value-of select="E-3035"/>
									</BlShipperPartyType>
									<BlShipperName>
										<xsl:value-of select="E-C080/C-3036"/>
									</BlShipperName>
									<BlShipperAddress>
										<xsl:value-of select="E-C058"/>
									</BlShipperAddress>
									<BlShipperCity>
										<xsl:value-of select="E-3164"/>
									</BlShipperCity>
									<BlShipperCountry>
										<xsl:value-of select="E-3229"/>
									</BlShipperCountry>
								</BlShipper>
							</xsl:for-each>
							<xsl:choose>
								<xsl:when test="../Group11/NAD[E-3035='CX']">
									<xsl:for-each select="../Group11/NAD[E-3035='CX']">
										<BlNotify>
											<BlNtfyPartyType>
												<xsl:value-of select="E-3035"/>
											</BlNtfyPartyType>
											<BlNtfyrName>
												<xsl:value-of select="E-C080/C-3036"/>
											</BlNtfyrName>
											<BlNtfyAddress>
												<xsl:value-of select="E-C058"/>
											</BlNtfyAddress>
											<BlNtfyCity>
												<xsl:value-of select="E-3164"/>
											</BlNtfyCity>
											<BlNtfyCountry>
												<xsl:value-of select="E-3229"/>
											</BlNtfyCountry>
										</BlNotify>
									</xsl:for-each>
								</xsl:when>
								<xsl:otherwise>
									<xsl:for-each select="../Group11/NAD[E-3035='CN']">
										<BlNotify>
											<BlNtfyPartyType>
												<xsl:value-of select="E-3035"/>
											</BlNtfyPartyType>
											<BlNtfyrName>
												<xsl:value-of select="E-C080/C-3036"/>
											</BlNtfyrName>
											<BlNtfyAddress>
												<xsl:value-of select="E-C058"/>
											</BlNtfyAddress>
											<BlNtfyCity>
												<xsl:value-of select="E-3164"/>
											</BlNtfyCity>
											<BlNtfyCountry>
												<xsl:value-of select="E-3229"/>
											</BlNtfyCountry>
										</BlNotify>
									</xsl:for-each>
								</xsl:otherwise>
							</xsl:choose>
							<BlUdf>
								<Udf>
									<UdfCode CreateIfNotExists="Y"/>
									<UdfValue>
										<xsl:value-of select="Group24/DOC/E-1220[1]"/>
									</UdfValue>
								</Udf>
								<xsl:if test="LOC/E-3227 = '76'">
									<Udf>
										<UdfCode CreateIfNotExists="Y">POL</UdfCode>
										<UdfValue>
											<xsl:value-of select="LOC/E-C517/C-3224"/>
										</UdfValue>
									</Udf>
								</xsl:if>
								<xsl:if test="LOC/E-3227 = '12'">
									<Udf>
										<UdfCode CreateIfNotExists="Y">POD</UdfCode>
										<UdfValue>
											<xsl:value-of select="LOC/E-C517/C-3224"/>
										</UdfValue>
									</Udf>
								</xsl:if>
								<Udf>
									<UdfCode CreateIfNotExists="Y">
										<xsl:text>PayCond</xsl:text>
									</UdfCode>
									<UdfValue/>
								</Udf>
								<Udf>
									<UdfCode CreateIfNotExists="Y">
										<xsl:text>StichWort</xsl:text>
									</UdfCode>
									<UdfValue>
										<xsl:value-of select="FTX[E-4451='AAW']/E-C108/C-4440[1]"/>
									</UdfValue>
								</Udf>
								<Udf>
									<UdfCode CreateIfNotExists="N">EdiBL</UdfCode>
									<UdfValue>Y</UdfValue>
								</Udf>
							</BlUdf>
						</BillOfLading>
					</GoodBillsOfLading>
					<Containers>
						<xsl:for-each select="Group29">
							<Container>
								<xsl:variable name="contnr" select="SGP/E-C237/C-8260"/>
								<xsl:for-each select="$containers//Container[ContContainerNumber = $contnr]">
									<ContainerID>
										<xsl:value-of select="ID"/>
									</ContainerID>
								</xsl:for-each>
							</Container>
						</xsl:for-each>
					</Containers>
				</GoodLine>
			</xsl:for-each>
		</FileGoodLines>
		<FileContainers DeletePrevious="Y">
			<xsl:for-each select="Group37">
				<xsl:variable name="contnr" select="EQD/E-C237/C-8260"/>
				<xsl:if test="../Group18/Group29/SGP/E-C237[C-8260 = $contnr]">
					<Container>
						<xsl:for-each select="$containers//Container[ContContainerNumber = $contnr]">
							<ID>
								<xsl:value-of select="ID"/>
							</ID>
						</xsl:for-each>
						<ContContainerNumber>
							<xsl:value-of select="EQD/E-C237/C-8260"/>
						</ContContainerNumber>
						<ContSizeOfContainer>
							<xsl:value-of select="substring(EQD/E-C224/C-8155, 1, 2)"/>
						</ContSizeOfContainer>
						<ContTypeOfContainer>
							<xsl:value-of select="substring(EQD/E-C224/C-8155, 3)"/>
						</ContTypeOfContainer>
						<xsl:for-each select="MEA">
							<xsl:if test="E-6311 = 'WT'">
								<xsl:if test="E-C502/C-6313 = 'AAB'">
									<ContSizeOfContainer>
										<xsl:value-of select="E-C174/C-6314 div 1000"/>
									</ContSizeOfContainer>
								</xsl:if>
								<xsl:if test="E-C502/C-6313 = 'AAE'">
									<ContNettWeight>
										<xsl:value-of select="E-C174/C-6314"/>
									</ContNettWeight>
								</xsl:if>
							</xsl:if>
						</xsl:for-each>
						<ContSeal1>
							<xsl:value-of select="SEL[1]/E-9308"/>
						</ContSeal1>
						<ContSeal2>
							<xsl:value-of select="SEL[2]/E-9308"/>
						</ContSeal2>
						<ContSealNumbers>
							<SealNumber>
								<Seal1>
									<xsl:value-of select="SEL[1]/E-9308"/>
								</Seal1>
								<Seal2>
									<xsl:value-of select="SEL[2]/E-9308"/>
								</Seal2>
							</SealNumber>
						</ContSealNumbers>
						<ContTranshipment>
							<xsl:value-of select="TMD/E-C219/C-8335"/>
						</ContTranshipment>
						<ContainerUdf>
							<xsl:for-each select="MEA[E-C502/C-6154='VGM']">
								<Udf>
									<UdfCode CreateIfNotExists="Y">SOLAS_VW</UdfCode>
									<UdfValue>
										<xsl:value-of select="E-C174/C-6314"/>
									</UdfValue>
								</Udf>
							</xsl:for-each>
							<!--FTX+AAF+++Empty container free ex port of presentation to customs'-->
							<xsl:for-each select="FTX[E-4451 = 'AAF']">
								<Udf>
									<UdfCode CreateIfNotExists="Y">FTX-AAF</UdfCode>
									<UdfValue>
										<xsl:value-of select="E-C108/C-4440"/>
									</UdfValue>
								</Udf>
							</xsl:for-each>
							<xsl:for-each select="FTX">
								<xsl:choose>
									<xsl:when test="E-4451='ABL'">
										<xsl:if test="E-C107/C-4441='VGM'">
											<Udf>
												<UdfCode CreateIfNotExists="Y">SOLAS_TX</UdfCode>
												<UdfValue>
													<xsl:value-of select="E-C108/C-4440"/>
												</UdfValue>
											</Udf>
										</xsl:if>
									</xsl:when>
									<xsl:when test="E-4451='ZZZ'">
										<xsl:if test="E-C107/C-4441='VGM'">
											<Udf>
												<UdfCode CreateIfNotExists="Y">SOLAS_MCA</UdfCode>
												<UdfValue>
													<xsl:value-of select="E-C108/C-4440"/>
												</UdfValue>
											</Udf>
										</xsl:if>
									</xsl:when>
								</xsl:choose>
							</xsl:for-each>
						</ContainerUdf>
					</Container>
				</xsl:if>
			</xsl:for-each>
		</FileContainers>
	</xsl:template>
	<xsl:template name="iftminSegment_BL00">
		<xsl:variable name="portOfDischarge">
			<xsl:value-of select="Group8/Group9/LOC[E-3227 = 12]/E-C517/C-3225"/>
		</xsl:variable>
		<xsl:variable name="portOfDischargeName">
			<xsl:value-of select="Group8/Group9/LOC[E-3227 = 12]/E-C517/C-3224"/>
		</xsl:variable>
		<xsl:variable name="portOfLoading">
			<xsl:value-of select="Group8/Group9/LOC[E-3227 = 5]/E-C517/C-3225"/>
		</xsl:variable>
		<xsl:variable name="portOfLoadingName">
			<xsl:value-of select="Group8/Group9/LOC[E-3227 = 5]/E-C517/C-3224"/>
		</xsl:variable>
		<xsl:variable name="PositionFile">
			<xsl:value-of select="position()"/>
		</xsl:variable>
		<SearchFields>
			<SearchField>REFCFL</SearchField>
			<SearchField>STFLFL</SearchField>
		</SearchFields>
		<FileTypeOfFile>OP</FileTypeOfFile>
		<xsl:for-each select="Group11/NAD[E-3035='CZ']">
			<FileThirdParty>
				<xsl:attribute name="ThirdPartyID" select="E-C082/C-3039"/>BASF</FileThirdParty>
		</xsl:for-each>
		<FileImportExport>E</FileImportExport>
		
		<xsl:choose>
			<xsl:when test="	FTX[E-4451='SIC']/E-C108/C-4440[contains(lower-case(.), 'house')] or 
								FTX[E-4451='SIC']/E-C108/C-4440[contains(lower-case(.), 'haus')] or 
								FTX[E-4451='SIC']/E-C108/C-4440[contains(lower-case(.), 'hause')] or 
								FTX[E-4451='AAS']/E-C108/C-4440[contains(lower-case(.), 'house')] or 
								FTX[E-4451='AAS']/E-C108/C-4440[contains(lower-case(.), 'haus')] or 
								FTX[E-4451='AAS']/E-C108/C-4440[contains(lower-case(.), 'hause')]">
				<FileStatus>MB</FileStatus>
				<xsl:choose>
					<xsl:when test="//NAD[E-3035='FW']/E-C082/C-3039 = '2683269' or //NAD[E-3035='FW']/E-C082/C-3039 = '5904903'">
						<FileScenario>72BASF HBL</FileScenario>
					</xsl:when>
					<xsl:when test="//NAD[E-3035='FW']/E-C082/C-3039 = '4953206'">
						<FileScenario>74BASF HBL</FileScenario>
					</xsl:when>
					<xsl:otherwise>
						<FileScenario>71BASF HBL</FileScenario>
					</xsl:otherwise>
				</xsl:choose>
			</xsl:when>
			<xsl:otherwise>
				<FileStatus>RB</FileStatus>
				<xsl:choose>
					<xsl:when test="//NAD[E-3035='FW']/E-C082/C-3039 = '2683269' or //NAD[E-3035='FW']/E-C082/C-3039 = '5904903'">
						<FileScenario>72BASF RBL</FileScenario>
					</xsl:when>
					<xsl:when test="//NAD[E-3035='FW']/E-C082/C-3039 = '4953206'">
						<FileScenario>74BASF RBL</FileScenario>
					</xsl:when>
					<xsl:otherwise>
						<FileScenario>71BASF RBL</FileScenario>
					</xsl:otherwise>
				</xsl:choose>
			</xsl:otherwise>
		</xsl:choose>
		
		<xsl:if test="not(Group37)">
			<xsl:choose>
				<xsl:when test="//NAD[E-3035='FW']/E-C082/C-3039 = '2683269' or //NAD[E-3035='FW']/E-C082/C-3039 = '5904903'">
					<FileTempFile>N</FileTempFile>
				</xsl:when>
				<xsl:otherwise>
					<FileTempFile>Y</FileTempFile>
				</xsl:otherwise>
			</xsl:choose>
		</xsl:if>
		<FileCustomerReference>
			<xsl:value-of select="BGM/E-C106/C-1004"/>
			<xsl:value-of select="'BL00'"/>
		</FileCustomerReference>
		<xsl:if test="Group3/RFF[E-C506/C-1153 = 'BN']">
			<FileAgentReference>
				<xsl:value-of select="Group3/RFF/E-C506[C-1153 = 'BN']/C-1154"/>
			</FileAgentReference>
		</xsl:if>
		<xsl:for-each select="Group8/TDT[E-8051 = 20]/E-C220[C-8067 = 10]">
			<FileMainCarriage>
				<xsl:value-of select="../E-C222/C-8212"/>
			</FileMainCarriage>
		</xsl:for-each>
		<FileMainCarriageQualifier>VSSEL</FileMainCarriageQualifier>
		<xsl:for-each select="Group8/DTM/E-C507[C-2005 = 132]">
			<FileEts Format="DD/MM/YYYY">
				<xsl:call-template name="formatDate">
					<xsl:with-param name="date" select="C-2380"/>
				</xsl:call-template>
			</FileEts>
		</xsl:for-each>
		<xsl:for-each select="Group8/DTM/E-C507[C-2005 = 133]">
			<FileEtd Format="DD/MM/YYYY">
				<xsl:call-template name="formatDate">
					<xsl:with-param name="date" select="C-2380"/>
				</xsl:call-template>
			</FileEtd>
		</xsl:for-each>
		<FileCompany>
			<xsl:if test="//NAD[E-3035='FW']/E-C082/C-3039 = '2683269' or //NAD[E-3035='FW']/E-C082/C-3039 = '5904903'">FPLES</xsl:if>
			<xsl:if test="//NAD[E-3035='FW']/E-C082/C-3039 = '4953206'">FRACHTITA</xsl:if>
			<xsl:if test="$portOfLoading = 'DEHAM'">POLYTRA</xsl:if>
			<xsl:if test="$portOfLoading = 'DEBRV'">POLYTRA</xsl:if>
		</FileCompany>
		<FileGroup>
			<xsl:if test="//NAD[E-3035='FW']/E-C082/C-3039 = '2683269' or //NAD[E-3035='FW']/E-C082/C-3039 = '5904903'">BASFES</xsl:if>
			<xsl:if test="//NAD[E-3035='FW']/E-C082/C-3039 = '4953206'">01</xsl:if>
			<xsl:if test="$portOfLoading = 'DEHAM'">BASFHA</xsl:if>
			<xsl:if test="$portOfLoading = 'DEBRV'">BASFHA</xsl:if>
		</FileGroup>
		<FileDepartment>
			<xsl:if test="//NAD[E-3035='FW']/E-C082/C-3039 = '2683269' or //NAD[E-3035='FW']/E-C082/C-3039 = '5904903'">72</xsl:if>
			<xsl:if test="//NAD[E-3035='FW']/E-C082/C-3039 = '4953206'">74</xsl:if>
			<xsl:if test="$portOfLoading = 'DEHAM'">70</xsl:if>
			<xsl:if test="$portOfLoading = 'DEBRV'">70</xsl:if>
		</FileDepartment>
		<FileUser/>
		<FileContactName/>
		<xsl:for-each select="Group11/NAD[E-3035 = 'CA']">
			<FileTransportCompany>
				<xsl:value-of select="concat(E-C082/C-3039,'_CA')"/>
			</FileTransportCompany>
		</xsl:for-each>
		<FilePortOfLoading>
			<xsl:value-of select="$portOfLoading"/>
		</FilePortOfLoading>
		<FilePortOfLoadingName>
			<xsl:value-of select="$portOfLoadingName"/>
		</FilePortOfLoadingName>
		<FilePortOfDischarge>
			<xsl:value-of select="$portOfDischarge"/>
		</FilePortOfDischarge>
		<FilePortOfDischargeName>
			<xsl:value-of select="$portOfDischargeName"/>
		</FilePortOfDischargeName>
		<xsl:for-each select="Group18[1]/LOC[E-3227 = 1][1]">
			<FileFinalDestination>
				<xsl:value-of select="E-C517/C-3224"/>
			</FileFinalDestination>
		</xsl:for-each>
		<xsl:for-each select="Group18[1]/LOC[E-3227 = 1][1]">
			<FileTermsOfDelivery Delimiter="|">
				<xsl:value-of select="E-C517/C-3225"/>
				<!--
				<xsl:choose>
					<xsl:when test="E-C517/C-3225 = 'FCA'">FOB</xsl:when>
					<xsl:otherwise><xsl:value-of select="E-C517/C-3225"/></xsl:otherwise>
				</xsl:choose>
				-->
			</FileTermsOfDelivery>
		</xsl:for-each>
		<FileReserveFields>
			<xsl:for-each select="Group8/Group9/LOC[E-3227 = 12]">
				<ReserveField4>
					<xsl:value-of select="substring(E-C517/C-3225, 1, 2)"/>
				</ReserveField4>
			</xsl:for-each>
		</FileReserveFields>
		<FileUdf>
			<xsl:for-each select="Group8/TDT[E-8051 = 20]/E-C220[C-8067 = 10]">
				<Udf>
					<UdfCode CreateIfNotExists="Y">NEW-LLOYD</UdfCode>
					<UdfValue>
						<xsl:value-of select="../E-C222/C-8213"/>
					</UdfValue>
				</Udf>
			</xsl:for-each>
			<xsl:for-each select="Group8/TDT[E-8051 = 20]">
				<Udf>
					<UdfCode CreateIfNotExists="Y">VOYNBR</UdfCode>
					<UdfValue>
						<xsl:value-of select="E-8028"/>
					</UdfValue>
				</Udf>
			</xsl:for-each>
			<Udf>
				<UdfCode CreateIfNotExists="Y">Place-TOD</UdfCode>
				<UdfValue>
					<xsl:value-of select="Group18[1]/LOC[E-3227 = 1][1]/E-C517[1]/C-3224[1]"/>
				</UdfValue>
			</Udf>
			<Udf>
				<UdfCode CreateIfNotExists="Y">Place-TOD20</UdfCode>
				<UdfValue>
					<xsl:value-of select="Group8/Group9/LOC[E-3227 = 20][1]/E-C517[1]/C-3225[1]"/>
				</UdfValue>
			</Udf>
			<xsl:for-each select="CTA[E-3139='MS']">
				<Udf>
					<UdfCode CreateIfNotExists="Y">Sped-CTA</UdfCode>
					<UdfValue>
						<xsl:value-of select="E-C056/C-3412"/>
					</UdfValue>
				</Udf>
			</xsl:for-each>
			<xsl:for-each select="COM/E-C076[C-3155='TE']">
				<Udf>
					<UdfCode CreateIfNotExists="Y">Sped-TEL</UdfCode>
					<UdfValue>
						<xsl:value-of select="C-3148"/>
					</UdfValue>
				</Udf>
			</xsl:for-each>
			<xsl:for-each select="COM/E-C076[C-3155='FX']">
				<Udf>
					<UdfCode CreateIfNotExists="Y">Sped-FAX</UdfCode>
					<UdfValue>
						<xsl:value-of select="C-3148"/>
					</UdfValue>
				</Udf>
			</xsl:for-each>
			<Udf>
				<UdfCode>MessageFunction</UdfCode>
				<UdfValue>
					<xsl:value-of select="BGM/E-1225"/>
				</UdfValue>
			</Udf>
			<Udf>
				<UdfCode CreateIfNotExists="Y">MesFu</UdfCode>
				<UdfValue>
					<xsl:value-of select="BGM/E-1225"/>
				</UdfValue>
			</Udf>
			<xsl:for-each select="Group8/Group9/LOC[E-3227 = 13]">
				<Udf>
					<UdfCode CreateIfNotExists="Y">PLCOFTRNSSHPM</UdfCode>
					<UdfValue>
						<xsl:value-of select="E-C519/C-3223"/>
					</UdfValue>
				</Udf>
			</xsl:for-each>
			<!-- Alle FTX-segmenten <Udf> -->
			<xsl:for-each-group select="descendant::FTX[not(ancestor-or-self::Group18)]" group-by="E-4451">
				<Udf>
					<UdfCode CreateIfNotExists="Y">
						<xsl:text>FTX-</xsl:text>
						<xsl:value-of select="current-grouping-key()"/>
					</UdfCode>
					<UdfValue>
						<!-- TRFS 28/03/2012 
								 -> Add the value of BGM segment in the FTX-ABO segment.
								    If this isn't done, the KPI's and containers aren't processed correctly! -->
						<xsl:if test="current-grouping-key()='ABO'">
							<xsl:value-of select="/IFTMIN/MESSAGE/Group0/BGM/E-C002/C-1000"/>
							<xsl:text> &#xD; </xsl:text>
						</xsl:if>
						<xsl:for-each select="current-group()/E-C108/C-4440">
							<xsl:value-of select="."/>
						</xsl:for-each>
					</UdfValue>
				</Udf>
			</xsl:for-each-group>
			<xsl:for-each-group select="Group3/RFF | Group8/Group10/RFF | Group11/Group15/RFF | Group11/Group16/RFF | Group11/Group17/RFF | Group37/RFF" group-by="E-C506/C-1153">
				<Udf>
					<UdfCode CreateIfNotExists="Y">
						<xsl:text>RFF-</xsl:text>
						<xsl:value-of select="current-grouping-key()"/>
					</UdfCode>
					<UdfValue>
						<xsl:value-of select="string-join(current-group()/E-C506/C-1154, ';')"/>
					</UdfValue>
				</Udf>
				<xsl:if test="current-grouping-key() = 'LI'">
					<Udf>
						<UdfCode CreateIfNotExists="Y">
							<xsl:text>RFF-LI2</xsl:text>
						</UdfCode>
						<UdfValue>
							<xsl:value-of select="fn:string-join(current-group()/E-C506/C-1156, ';')"/>
						</UdfValue>
					</Udf>
				</xsl:if>
			</xsl:for-each-group>
			<Udf>
				<UdfCode CreateIfNotExists="Y">
					<xsl:text>UNH</xsl:text>
				</UdfCode>
				<UdfValue>
					<xsl:value-of select="UNH/E-0068"/>
				</UdfValue>
			</Udf>
			<Udf>
				<UdfCode CreateIfNotExists="Y">TMD</UdfCode>
				<UdfValue>
					<xsl:value-of select="Group37[1]/TMD/E-C219/C-8334"/>
				</UdfValue>
			</Udf>
			<xsl:for-each select="Group8/TSR/E-C536/C-4065">
				<xsl:if test="position() = 1">
					<xsl:variable name="tempContrCarriage">
						<xsl:value-of select="./text()"/>
					</xsl:variable>
					<Udf>
						<UdfCode CreateIfNotExists="Y">ContrCarriage-code</UdfCode>
						<UdfValue>
							<xsl:value-of select="$tempContrCarriage"/>
						</UdfValue>
					</Udf>
					<Udf>
						<UdfCode CreateIfNotExists="Y">ContrCarriage-desc</UdfCode>
						<UdfValue>
							<xsl:value-of select="$contrCarriage/Value[@id = $tempContrCarriage]"/>
						</UdfValue>
					</Udf>
				</xsl:if>
			</xsl:for-each>
			<xsl:for-each select="Group37/TMD/E-C219/C-8335">
				<xsl:if test="position() = 1">
					<xsl:variable name="tempBeladeart">
						<xsl:value-of select="./text()"/>
					</xsl:variable>
					<Udf>
						<UdfCode CreateIfNotExists="Y">Beladeart-code</UdfCode>
						<UdfValue>
							<xsl:value-of select="$tempBeladeart"/>
						</UdfValue>
					</Udf>
					<Udf>
						<UdfCode CreateIfNotExists="Y">Beladeart-desc</UdfCode>
						<UdfValue>
							<xsl:value-of select="replace($beladeart/Value[@id = $tempBeladeart],'/','')"/>
						</UdfValue>
					</Udf>
				</xsl:if>
			</xsl:for-each>
			<Udf>
				<UdfCode CreateIfNotExists="Y">UNB_DT</UdfCode>
				<UdfValue>
					<xsl:value-of select="../UNB/E-S004/C-0017"/>
					<xsl:text>-</xsl:text>
					<xsl:value-of select="../UNB/E-S004/C-0019"/>
				</UdfValue>
			</Udf>
			<Udf>
				<UdfCode CreateIfNotExists="Y">UNH_NR</UdfCode>
				<UdfValue>
					<xsl:value-of select="UNH/E-0062"/>
				</UdfValue>
			</Udf>
		</FileUdf>
		<FileParties DeletePrevious="N">
			<!-- Shipper (OS), Consignee (DO) en Notify (N1-N2) overslaan voor mainfile, manueel instellen per landcode uit POD -->
			<xsl:choose>
				<xsl:when test="$portOfDischarge = 'BRSSZ'">
					<Party Type="OS">
						<PartyDescription>ECU WORLDWIDE BELGIUM N.V.</PartyDescription>
						<PartyId/>
						<PartyAddressName>Schomhoeveweg 15</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode>2030</PartyAddressZipcode>
						<PartyAddressCity>Antwerp</PartyAddressCity>
						<PartyContactTelephone>0032 3 541 24 66</PartyContactTelephone>
						<PartyContactFax>As agents only</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:text>OS|ECU WORLDWIDE BELGIUM N.V.&#xD;Schomhoeveweg 15&#xD;2030 Antwerp&#xD;Tel: 0032 3 541 24 66&#xD;As agents only</xsl:text>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="DO">
						<PartyDescription>ECU WORLDWIDE LOGISTICS DO BRAZIL LTDA</PartyDescription>
						<PartyId/>
						<PartyAddressName>Rua Bela Cintra 904 1 andar CJ 11 Consolacao/CNPJ 05.221.721//0001-45/01415-002 SAO PAULO/BRAZIL</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode/>
						<PartyAddressCity/>
						<PartyContactTelephone>0 55 11 2596-8100</PartyContactTelephone>
						<PartyContactFax/>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'DO|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="N1">
						<PartyDescription>ECU WORLDWIDE (BRASIL) LTDA</PartyDescription>
						<PartyId/>
						<PartyAddressName>Rua Bela Cintra 904 1 andar CJ 11 Consolacao/CNPJ 05.221.721//0001-45/01415-002 SAO PAULO/BRAZIL</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode/>
						<PartyAddressCity/>
						<PartyContactTelephone>0 55 11 2596-8100</PartyContactTelephone>
						<PartyContactFax/>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'N1|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
				</xsl:when>
				<xsl:when test="$portOfDischarge = 'KRPUS'">
					<Party Type="OS">
						<PartyDescription>POLYTRA NV AS AGENT OF BASF SE</PartyDescription>
						<PartyId/>
						<PartyAddressName/>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry>DE</PartyAddressCountry>
						<PartyAddressZipcode>67056</PartyAddressZipcode>
						<PartyAddressCity>LUDWIGSHAFEN</PartyAddressCity>
						<PartyContactTelephone/>
						<PartyContactFax/>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:text>OS|POLYTRA NV AS AGENT OF BASF SE&#xD;67056 LUDWIGSHAFEN&#xD;GERMANY</xsl:text>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="DO">
						<PartyDescription>MOLAX LINE LTD.</PartyDescription>
						<PartyId/>
						<PartyAddressName>10F 116 SEOSOMUN-RO JUNG-GU SEOUL,/KOREA</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode/>
						<PartyAddressCity/>
						<PartyContactTelephone>82 +82 2 310 4401</PartyContactTelephone>
						<PartyContactFax>82 +82 2 757</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'DO|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="N1">
						<PartyDescription>MOLAX LINE LTD.</PartyDescription>
						<PartyId/>
						<PartyAddressName>10F 116 SEOSOMUN-RO JUNG-GU SEOUL,/KOREA</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode/>
						<PartyAddressCity/>
						<PartyContactTelephone>82 +82 2 310 4401</PartyContactTelephone>
						<PartyContactFax>82 +82 2 757</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'DO|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
				</xsl:when>
				<xsl:when test="$portOfDischarge = 'CNSHA'">
					<Party Type="OS">
						<PartyDescription>POLYTRA NV AS AGENT OF BASF SE</PartyDescription>
						<PartyId/>
						<PartyAddressName/>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry>DE</PartyAddressCountry>
						<PartyAddressZipcode>67056</PartyAddressZipcode>
						<PartyAddressCity>LUDWIGSHAFEN</PartyAddressCity>
						<PartyContactTelephone/>
						<PartyContactFax/>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:text>OS|POLYTRA NV AS AGENT OF BASF SE&#xD;67056 LUDWIGSHAFEN&#xD;GERMANY</xsl:text>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="DO">
						<PartyDescription>SHANGHAI HUASING INTERNATIONAL</PartyDescription>
						<PartyId/>
						<PartyAddressName>CONTAINER FREIGHT/TRANSPORTATION CO LTD./12A, NO//.369 TANGGU ROAD/SHANGHAI, CHINA 200080</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode/>
						<PartyAddressCity/>
						<PartyContactTelephone>86-21-63063463</PartyContactTelephone>
						<PartyContactFax>86-21-63931028</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'DO|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="N1">
						<PartyDescription>ECU WORLDWIDE (SHANGAI) LTD.</PartyDescription>
						<PartyId/>
						<PartyAddressName>9F, BUILDING B, SILVERBAY TOWER/469 WUSONG ROAD</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry>CN</PartyAddressCountry>
						<PartyAddressZipcode>200080</PartyAddressZipcode>
						<PartyAddressCity>SHANGHAI</PartyAddressCity>
						<PartyContactTelephone>00 86 21/63 64 33 99</PartyContactTelephone>
						<PartyContactFax>00 86 21.63 64 33 91</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'N1|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
				</xsl:when>
				<xsl:when test="$portOfDischarge = 'CNSGH'">
					<Party Type="OS">
						<PartyDescription>POLYTRA NV AS AGENT OF BASF SE</PartyDescription>
						<PartyId/>
						<PartyAddressName/>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry>DE</PartyAddressCountry>
						<PartyAddressZipcode>67056</PartyAddressZipcode>
						<PartyAddressCity>LUDWIGSHAFEN</PartyAddressCity>
						<PartyContactTelephone/>
						<PartyContactFax/>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:text>OS|POLYTRA NV AS AGENT OF BASF SE&#xD;67056 LUDWIGSHAFEN&#xD;GERMANY</xsl:text>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="DO">
						<PartyDescription>SHANGHAI HUASING INTERNATIONAL</PartyDescription>
						<PartyId/>
						<PartyAddressName>CONTAINER FREIGHT/TRANSPORTATION CO LTD./12A, NO//.369 TANGGU ROAD/SHANGHAI, CHINA 200080</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode/>
						<PartyAddressCity/>
						<PartyContactTelephone>86-21-63063463</PartyContactTelephone>
						<PartyContactFax>86-21-63931028</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'DO|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="N1">
						<PartyDescription>ECU WORLDWIDE (SHANGHAI) LTD.</PartyDescription>
						<PartyId/>
						<PartyAddressName>9F, BUILDING B, SILVERBAY TOWER/469 WUSONG ROAD/200080 SHANGHAI CHINA</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode/>
						<PartyAddressCity/>
						<PartyContactTelephone>00 86 21/63 64 33 99</PartyContactTelephone>
						<PartyContactFax>00 86 21.63 64 33 91</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'N1|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
				</xsl:when>
				<xsl:when test="$portOfDischarge = 'CLVAP'">
					<Party Type="OS">
						<PartyDescription>ECU WORLDWIDE BELGIUM N.V.</PartyDescription>
						<PartyId/>
						<PartyAddressName>Schomhoeveweg 15</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode>2030</PartyAddressZipcode>
						<PartyAddressCity>Antwerp</PartyAddressCity>
						<PartyContactTelephone>0032 3 541 24 66</PartyContactTelephone>
						<PartyContactFax>As agents only</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:text>OS|ECU WORLDWIDE BELGIUM N.V.&#xD;Schomhoeveweg 15&#xD;2030 Antwerp&#xD;Tel: 0032 3 541 24 66&#xD;As agents only</xsl:text>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="DO">
						<PartyDescription>ECU WORLDWIDE CHILE S.A.</PartyDescription>
						<PartyId/>
						<PartyAddressName>AMERICO VESPUCIO 80/PISO 8, OFIC. 81 Y 82/LAS CONDES - SANTIAGO CHILE</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode/>
						<PartyAddressCity/>
						<PartyContactTelephone>00 56 2/2430.6600</PartyContactTelephone>
						<PartyContactFax>00 56 5623660164</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'DO|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="N1">
						<PartyDescription>ECU WORLDWIDE CHILE S.A.</PartyDescription>
						<PartyId/>
						<PartyAddressName>AMERICO VESPUCIO 80/PISO 8, OFIC. 81 Y 82/LAS CONDES - SANTIAGO CHILE</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode/>
						<PartyAddressCity/>
						<PartyContactTelephone>00 56 2/2430.6600</PartyContactTelephone>
						<PartyContactFax>00 56 5623660164</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'N1|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
				</xsl:when>
				<xsl:when test="$portOfDischarge = 'PECLL'">
					<Party Type="OS">
						<PartyDescription>ECU WORLDWIDE BELGIUM N.V.</PartyDescription>
						<PartyId/>
						<PartyAddressName>Schomhoeveweg 15</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode>2030</PartyAddressZipcode>
						<PartyAddressCity>Antwerp</PartyAddressCity>
						<PartyContactTelephone>0032 3 541 24 66</PartyContactTelephone>
						<PartyContactFax>As agents only</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:text>OS|ECU WORLDWIDE BELGIUM N.V.&#xD;Schomhoeveweg 15&#xD;2030 Antwerp&#xD;Tel: 0032 3 541 24 66&#xD;As agents only</xsl:text>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="DO">
						<PartyDescription>ECU WORLDWIDE PERU SAC.</PartyDescription>
						<PartyId/>
						<PartyAddressName>RUC20556687529/AV. ELMER FAUCETT N° 2851/OF. 315 CALLAO</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry>PE</PartyAddressCountry>
						<PartyAddressZipcode/>
						<PartyAddressCity>LIMA</PartyAddressCity>
						<PartyContactTelephone>00 51 1619.5100</PartyContactTelephone>
						<PartyContactFax>00 51 1619.5120</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'DO|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="N1">
						<PartyDescription>ECU WORLDWIDE PERU SAC.</PartyDescription>
						<PartyId/>
						<PartyAddressName>RUC20556687529/AV. ELMER FAUCETT N° 2851/OF. 315 CALLAO</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry>PE</PartyAddressCountry>
						<PartyAddressZipcode/>
						<PartyAddressCity>LIMA</PartyAddressCity>
						<PartyContactTelephone>00 51 1619.5100</PartyContactTelephone>
						<PartyContactFax>00 51 1619.5120</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'N1|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
				</xsl:when>
				<xsl:when test="$portOfDischarge = 'COCTG'">
					<Party Type="OS">
						<PartyDescription>ECU WORLDWIDE BELGIUM N.V.</PartyDescription>
						<PartyId/>
						<PartyAddressName>Schomhoeveweg 15</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode>2030</PartyAddressZipcode>
						<PartyAddressCity>Antwerp</PartyAddressCity>
						<PartyContactTelephone>0032 3 541 24 66</PartyContactTelephone>
						<PartyContactFax>As agents only</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:text>OS|ECU WORLDWIDE BELGIUM N.V.&#xD;Schomhoeveweg 15&#xD;2030 Antwerp&#xD;Tel: 0032 3 541 24 66&#xD;As agents only</xsl:text>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="DO">
						<PartyDescription>ECU WORLDWIDE (COLOMBIA) S.A.S</PartyDescription>
						<PartyId/>
						<PartyAddressName>NIT 800.180.908-5/CALLE 26 NO 69 - 76/TORRE 3 (TIERRA) OF. 601/ELEMENTO BUILDING/169-11-001 BOGOTA/COLOMBIA</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode/>
						<PartyAddressCity/>
						<PartyContactTelephone>57 14139640</PartyContactTelephone>
						<PartyContactFax>57 114139640</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'DO|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="N1">
						<PartyDescription>ECU WORLDWIDE (COLOMBIA) S.A.S</PartyDescription>
						<PartyId/>
						<PartyAddressName>NIT 800.180.908-5/CALLE 26 NO 69 - 76/TORRE 3 (TIERRA) OF. 601/ELEMENTO BUILDING/169-11-001 BOGOTA/COLOMBIA</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode/>
						<PartyAddressCity/>
						<PartyContactTelephone>57 14139640</PartyContactTelephone>
						<PartyContactFax>57 114139640</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'N1|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
				</xsl:when>
				<xsl:when test="$portOfDischarge = 'SGSIN'">
					<Party Type="OS">
						<PartyDescription>POLYTRA NV AS AGENT OF BASF SE</PartyDescription>
						<PartyId/>
						<PartyAddressName/>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry>DE</PartyAddressCountry>
						<PartyAddressZipcode>67056</PartyAddressZipcode>
						<PartyAddressCity>LUDWIGSHAFEN</PartyAddressCity>
						<PartyContactTelephone/>
						<PartyContactFax/>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:text>OS|POLYTRA NV AS AGENT OF BASF SE&#xD;67056 LUDWIGSHAFEN&#xD;GERMANY</xsl:text>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="DO">
						<PartyDescription>ECU WORLDWIDE (SINGAPORE) PTE LTD.</PartyDescription>
						<PartyId/>
						<PartyAddressName>237 PANDAN LOOP, 06-06 TO 06-11/WESTECH BUILDING</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry>SG</PartyAddressCountry>
						<PartyAddressZipcode>128424</PartyAddressZipcode>
						<PartyAddressCity>SINGAPORE</PartyAddressCity>
						<PartyContactTelephone>00 65 6220 3373</PartyContactTelephone>
						<PartyContactFax>00 65 6220 1366</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'DO|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="N1">
						<PartyDescription>ECU WORLDWIDE (SINGAPORE) PTE LTD.</PartyDescription>
						<PartyId/>
						<PartyAddressName>237 PANDAN LOOP, 06-06 TO 06-11/WESTECH BUILDING</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry>SG</PartyAddressCountry>
						<PartyAddressZipcode>128424</PartyAddressZipcode>
						<PartyAddressCity>SINGAPORE</PartyAddressCity>
						<PartyContactTelephone>00 65 6220 3373</PartyContactTelephone>
						<PartyContactFax>00 65 6220 1366</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'N1|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
				</xsl:when>
				<xsl:when test="$portOfDischarge = 'PHMNN'">
					<Party Type="OS">
						<PartyDescription>POLYTRA NV AS AGENT OF BASF SE</PartyDescription>
						<PartyId/>
						<PartyAddressName/>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry>DE</PartyAddressCountry>
						<PartyAddressZipcode>67056</PartyAddressZipcode>
						<PartyAddressCity>LUDWIGSHAFEN</PartyAddressCity>
						<PartyContactTelephone/>
						<PartyContactFax/>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:text>OS|POLYTRA NV AS AGENT OF BASF SE&#xD;67056 LUDWIGSHAFEN&#xD;GERMANY</xsl:text>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="DO">
						<PartyDescription>ECU WORLDWIDE (PHILIPPINES) INC</PartyDescription>
						<PartyId/>
						<PartyAddressName>UNIT 804-805 ,8TH FLOOR,/SCAPE BUILDING, D. MACAPAGAL AVENUE/MOA COMPLEX,/1004 PASAY CITY PHILIPPINES</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode/>
						<PartyAddressCity/>
						<PartyContactTelephone>63 28383839</PartyContactTelephone>
						<PartyContactFax>63 2.404 06 71</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'DO|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="N1">
						<PartyDescription>ECU WORLDWIDE (PHILIPPINES) INC</PartyDescription>
						<PartyId/>
						<PartyAddressName>UNIT 804-805 ,8TH FLOOR,/SCAPE BUILDING, D. MACAPAGAL AVENUE/MOA COMPLEX,/1004 PASAY CITY PHILIPPINES</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode/>
						<PartyAddressCity/>
						<PartyContactTelephone>63 28383839</PartyContactTelephone>
						<PartyContactFax>63 2.404 06 71</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'N1|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
				</xsl:when>
				<xsl:when test="$portOfDischarge = 'PHMNL'">
					<Party Type="OS">
						<PartyDescription>POLYTRA NV AS AGENT OF BASF SE</PartyDescription>
						<PartyId/>
						<PartyAddressName/>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry>DE</PartyAddressCountry>
						<PartyAddressZipcode>67056</PartyAddressZipcode>
						<PartyAddressCity>LUDWIGSHAFEN</PartyAddressCity>
						<PartyContactTelephone/>
						<PartyContactFax/>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:text>OS|POLYTRA NV AS AGENT OF BASF SE&#xD;67056 LUDWIGSHAFEN&#xD;GERMANY</xsl:text>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="DO">
						<PartyDescription>ECU-LINE PHILIPPINES INC.</PartyDescription>
						<PartyId/>
						<PartyAddressName>UNIT D5 G//F ECHELON TOWER BLDG.,/2100 A. MABINI ST., MALATE, MANILA/1004 MALATE, MANILA PHILIPPINES</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode/>
						<PartyAddressCity/>
						<PartyContactTelephone>00 63 2.404 06 58</PartyContactTelephone>
						<PartyContactFax>00 63 2.404 06 71</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'DO|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="N1">
						<PartyDescription>ECU-LINE PHILIPPINES INC.</PartyDescription>
						<PartyId/>
						<PartyAddressName>UNIT D5 G//F ECHELON TOWER BLDG.,/2100 A. MABINI ST., MALATE, MANILA/1004 MALATE, MANILA PHILIPPINES</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode/>
						<PartyAddressCity/>
						<PartyContactTelephone>00 63 2.404 06 58</PartyContactTelephone>
						<PartyContactFax>00 63 2.404 06 71</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'N1|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
				</xsl:when>
				<xsl:when test="$portOfDischarge = 'PHMNS'">
					<Party Type="OS">
						<PartyDescription>POLYTRA NV AS AGENT OF BASF SE</PartyDescription>
						<PartyId/>
						<PartyAddressName/>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry>DE</PartyAddressCountry>
						<PartyAddressZipcode>67056</PartyAddressZipcode>
						<PartyAddressCity>LUDWIGSHAFEN</PartyAddressCity>
						<PartyContactTelephone/>
						<PartyContactFax/>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:text>OS|POLYTRA NV AS AGENT OF BASF SE&#xD;67056 LUDWIGSHAFEN&#xD;GERMANY</xsl:text>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="DO">
						<PartyDescription>ECU-LINE PHILIPPINES INC.</PartyDescription>
						<PartyId/>
						<PartyAddressName>UNIT D5 G//F ECHELON TOWER BLDG.,/2100 A. MABINI ST., MALATE, MANILA/1004 MALATE, MANILA PHILIPPINES</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode/>
						<PartyAddressCity/>
						<PartyContactTelephone>00 63 2.404 06 58</PartyContactTelephone>
						<PartyContactFax>00 63 2.404 06 71</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'DO|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="N1">
						<PartyDescription>ECU-LINE PHILIPPINES INC.</PartyDescription>
						<PartyId/>
						<PartyAddressName>UNIT D5 G//F ECHELON TOWER BLDG.,/2100 A. MABINI ST., MALATE, MANILA/1004 MALATE, MANILA PHILIPPINES</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode/>
						<PartyAddressCity/>
						<PartyContactTelephone>00 63 2.404 06 58</PartyContactTelephone>
						<PartyContactFax>00 63 2.404 06 71</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'N1|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
				</xsl:when>
				<xsl:when test="$portOfDischarge = 'IDJKT'">
					<Party Type="OS">
						<PartyDescription>POLYTRA NV AS AGENT OF BASF SE</PartyDescription>
						<PartyId/>
						<PartyAddressName/>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry>DE</PartyAddressCountry>
						<PartyAddressZipcode>67056</PartyAddressZipcode>
						<PartyAddressCity>LUDWIGSHAFEN</PartyAddressCity>
						<PartyContactTelephone/>
						<PartyContactFax/>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:text>OS|POLYTRA NV AS AGENT OF BASF SE&#xD;67056 LUDWIGSHAFEN&#xD;GERMANY</xsl:text>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="DO">
						<PartyDescription>PT. ECU WORLDWIDE INDONESIA</PartyDescription>
						<PartyId/>
						<PartyAddressName>Emerald Tower 6th Floor/JL. Boulevard Barat XB-3 RT 002/RW004 Kelapa Gading Barat/14240 JAKARTA/INDONESIA</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode/>
						<PartyAddressCity/>
						<PartyContactTelephone>00 62 2129450959</PartyContactTelephone>
						<PartyContactFax>00 62 2129451024</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'DO|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="N1">
						<PartyDescription>PT. ECU WORLDWIDE INDONESIA</PartyDescription>
						<PartyId/>
						<PartyAddressName>Emerald Tower 6th Floor/JL. Boulevard Barat XB-3 RT 002/RW004 Kelapa Gading Barat/14240 JAKARTA/INDONESIA</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode/>
						<PartyAddressCity/>
						<PartyContactTelephone>00 62 2129450959</PartyContactTelephone>
						<PartyContactFax>00 62 2129451024</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'N1|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
				</xsl:when>
				<xsl:when test="$portOfDischarge = 'INNSA'">
					<Party Type="OS">
						<PartyDescription>POLYTRA NV AS AGENT OF BASF SE</PartyDescription>
						<PartyId/>
						<PartyAddressName/>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry>DE</PartyAddressCountry>
						<PartyAddressZipcode>67056</PartyAddressZipcode>
						<PartyAddressCity>LUDWIGSHAFEN</PartyAddressCity>
						<PartyContactTelephone/>
						<PartyContactFax/>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:text>OS|POLYTRA NV AS AGENT OF BASF SE&#xD;67056 LUDWIGSHAFEN&#xD;GERMANY</xsl:text>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="DO">
						<PartyDescription>ALLCARGO LOGISTICS LTD.</PartyDescription>
						<PartyId/>
						<PartyAddressName>6TH FLOOR, AVASHYA HOUSE/CST ROAD, KALINA, SANTACRUZ (EAST)/400098 MUMBAI - MAHARASHTRA/INDIA</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode/>
						<PartyAddressCity/>
						<PartyContactTelephone>00 91 22-6679 8106</PartyContactTelephone>
						<PartyContactFax>00 91 22-6679 8185/195</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'DO|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="N1">
						<PartyDescription>ALLCARGO LOGISTICS LTD.</PartyDescription>
						<PartyId/>
						<PartyAddressName>6TH FLOOR, AVASHYA HOUSE/CST ROAD, KALINA, SANTACRUZ (EAST)/400098 MUMBAI - MAHARASHTRA/INDIA</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode/>
						<PartyAddressCity/>
						<PartyContactTelephone>00 91 22-6679 8106</PartyContactTelephone>
						<PartyContactFax>00 91 22-6679 8185/195</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'N1|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
				</xsl:when>
				<xsl:when test="$portOfDischarge = 'THBKK'">
					<Party Type="OS">
						<PartyDescription>POLYTRA NV AS AGENT OF BASF SE</PartyDescription>
						<PartyId/>
						<PartyAddressName/>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry>DE</PartyAddressCountry>
						<PartyAddressZipcode>67056</PartyAddressZipcode>
						<PartyAddressCity>LUDWIGSHAFEN</PartyAddressCity>
						<PartyContactTelephone/>
						<PartyContactFax/>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:text>OS|POLYTRA NV AS AGENT OF BASF SE&#xD;67056 LUDWIGSHAFEN&#xD;GERMANY</xsl:text>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="DO">
						<PartyDescription>ECU WORLDWIDE (THAILAND) CO. LTD.</PartyDescription>
						<PartyId/>
						<PartyAddressName>628, 5 TH FLOOR TRIPLE I BUILDING/SOI KLAB CHOM, NONSEE ROAD/CHONGNONSEE, YANNAWA,</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry>TH</PartyAddressCountry>
						<PartyAddressZipcode>10120</PartyAddressZipcode>
						<PartyAddressCity>BANGKOK</PartyAddressCity>
						<PartyContactTelephone>00 66 2/6818555</PartyContactTelephone>
						<PartyContactFax>00 66 2/6818262-5</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'DO|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="N1">
						<PartyDescription>ECU WORLDWIDE (THAILAND) CO. LTD.</PartyDescription>
						<PartyId/>
						<PartyAddressName>628, 5 TH FLOOR TRIPLE I BUILDING/SOI KLAB CHOM, NONSEE ROAD/CHONGNONSEE, YANNAWA,</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry>TH</PartyAddressCountry>
						<PartyAddressZipcode>10120</PartyAddressZipcode>
						<PartyAddressCity>BANGKOK</PartyAddressCity>
						<PartyContactTelephone>00 66 2/6818555</PartyContactTelephone>
						<PartyContactFax>00 66 2/6818262-5</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'N1|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
				</xsl:when>
				<xsl:when test="$portOfDischarge = 'ARBUE'">
					<Party Type="OS">
						<PartyDescription>ECU WORLDWIDE BELGIUM N.V.</PartyDescription>
						<PartyId/>
						<PartyAddressName>Schomhoeveweg 15</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode>2030</PartyAddressZipcode>
						<PartyAddressCity>Antwerp</PartyAddressCity>
						<PartyContactTelephone>0032 3 541 24 66</PartyContactTelephone>
						<PartyContactFax>As agents only</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:text>OS|ECU WORLDWIDE BELGIUM N.V.&#xD;Schomhoeveweg 15&#xD;2030 Antwerp&#xD;Tel: 0032 3 541 24 66&#xD;As agents only</xsl:text>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="DO">
						<PartyDescription>ECU WORLDWIDE (ARGENTINA) SA</PartyDescription>
						<PartyId/>
						<PartyAddressName>CUIT : 30-71020219-9/AV. BELGRANO 355, PISO 12/(C1092AAD) BUENOS AIRES/ARGENTINA</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode/>
						<PartyAddressCity/>
						<PartyContactTelephone>00 54 11 53 53 0200</PartyContactTelephone>
						<PartyContactFax>00 54 1152732323</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'DO|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="N1">
						<PartyDescription>ECU WORLDWIDE (ARGENTINA) SA</PartyDescription>
						<PartyId/>
						<PartyAddressName>CUIT : 30-71020219-9/AV. BELGRANO 355, PISO 12/(C1092AAD) BUENOS AIRES/ARGENTINA</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode/>
						<PartyAddressCity/>
						<PartyContactTelephone>00 54 11 53 53 0200</PartyContactTelephone>
						<PartyContactFax>00 54 1152732323</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'N1|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
				</xsl:when>
				<xsl:when test="$portOfDischarge = 'ZADUR'">
					<Party Type="OS">
						<PartyDescription>ECU-Line n.v.</PartyDescription>
						<PartyId/>
						<PartyAddressName>Schomhoeveweg 15</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode>2030</PartyAddressZipcode>
						<PartyAddressCity>Antwerp</PartyAddressCity>
						<PartyContactTelephone>0032 3 541 24 66</PartyContactTelephone>
						<PartyContactFax>As agents only</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:text>OS|ECU-Line n.v.&#xD;Schomhoeveweg 15&#xD;2030 Antwerp&#xD;Tel: 0032 3 541 24 66&#xD;As agents only</xsl:text>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="DO">
						<PartyDescription>ECU-LINE SOUTH AFRICA DUR PTY. LTD.</PartyDescription>
						<PartyId/>
						<PartyAddressName>306//310 STAMFORDHILL ROAD/SUITE 10, SUTTON SQUARE</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry>ZA</PartyAddressCountry>
						<PartyAddressZipcode>4001</PartyAddressZipcode>
						<PartyAddressCity>DURBAN</PartyAddressCity>
						<PartyContactTelephone>00 27 31 31 22262</PartyContactTelephone>
						<PartyContactFax>00 27 31 3122279</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'DO|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="N1">
						<PartyDescription>ECU-LINE SOUTH AFRICA DUR PTY. LTD.</PartyDescription>
						<PartyId/>
						<PartyAddressName>306//310 STAMFORDHILL ROAD/SUITE 10, SUTTON SQUARE</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry>ZA</PartyAddressCountry>
						<PartyAddressZipcode>4001</PartyAddressZipcode>
						<PartyAddressCity>DURBAN</PartyAddressCity>
						<PartyContactTelephone>00 27 31 31 22262</PartyContactTelephone>
						<PartyContactFax>00 27 31 3122279</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'N1|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
				</xsl:when>
				<xsl:when test="$portOfDischarge = 'VNSGN'">
					<Party Type="OS">
						<PartyDescription>POLYTRA NV AS AGENT OF BASF SE</PartyDescription>
						<PartyId/>
						<PartyAddressName/>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry>DE</PartyAddressCountry>
						<PartyAddressZipcode>67056</PartyAddressZipcode>
						<PartyAddressCity>LUDWIGSHAFEN</PartyAddressCity>
						<PartyContactTelephone/>
						<PartyContactFax/>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:text>OS|POLYTRA NV AS AGENT OF BASF SE&#xD;67056 LUDWIGSHAFEN&#xD;GERMANY</xsl:text>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="DO">
						<PartyDescription>ECU LINE VIETNAM CO.LTD</PartyDescription>
						<PartyId/>
						<PartyAddressName>23 STREET 8A - NAM LONG RESIDENTIAL AREA/TAN THUAN DONG WARD, DISTRICT 7/HOCHIMINH CITY VIETNAM</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry>ZA</PartyAddressCountry>
						<PartyAddressZipcode>4001</PartyAddressZipcode>
						<PartyAddressCity>DURBAN</PartyAddressCity>
						<PartyContactTelephone>00 84 837733737</PartyContactTelephone>
						<PartyContactFax>00 84 837734506</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'DO|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="N1">
						<PartyDescription>ECU LINE VIETNAM CO.LTD</PartyDescription>
						<PartyId/>
						<PartyAddressName>23 STREET 8A - NAM LONG RESIDENTIAL AREA/TAN THUAN DONG WARD, DISTRICT 7/HOCHIMINH CITY VIETNAM</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry>ZA</PartyAddressCountry>
						<PartyAddressZipcode>4001</PartyAddressZipcode>
						<PartyAddressCity>DURBAN</PartyAddressCity>
						<PartyContactTelephone>00 84 837733737</PartyContactTelephone>
						<PartyContactFax>00 84 837734506</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'N1|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
				</xsl:when>
				<xsl:when test="$portOfDischarge = 'TWKHH'">
					<Party Type="OS">
						<PartyDescription>POLYTRA NV AS AGENT OF BASF SE</PartyDescription>
						<PartyId/>
						<PartyAddressName/>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry>DE</PartyAddressCountry>
						<PartyAddressZipcode>67056</PartyAddressZipcode>
						<PartyAddressCity>LUDWIGSHAFEN</PartyAddressCity>
						<PartyContactTelephone/>
						<PartyContactFax/>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:text>OS|POLYTRA NV AS AGENT OF BASF SE&#xD;67056 LUDWIGSHAFEN&#xD;GERMANY</xsl:text>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="DO">
						<PartyDescription>ORIENTAL POWER LOGISTICS CO., LTD.</PartyDescription>
						<PartyId/>
						<PartyAddressName>6F - 1,/No 10, SUE WEI 4TH ROAD/KAOHSIUNG/TAIWAN</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode/>
						<PartyAddressCity/>
						<PartyContactTelephone>00 886 7 535 2901</PartyContactTelephone>
						<PartyContactFax>00 886 7 535 0511</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'DO|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="N1">
						<PartyDescription>ORIENTAL POWER LOGISTICS CO., LTD.</PartyDescription>
						<PartyId/>
						<PartyAddressName>6F - 1,/No 10, SUE WEI 4TH ROAD/KAOHSIUNG/TAIWAN</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode/>
						<PartyAddressCity/>
						<PartyContactTelephone>00 886 7 535 2901</PartyContactTelephone>
						<PartyContactFax>00 886 7 535 0511</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'N1|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
				</xsl:when>
				<xsl:when test="$portOfDischarge = 'MYPKY'">
					<Party Type="OS">
						<PartyDescription>POLYTRA NV AS AGENT OF BASF SE</PartyDescription>
						<PartyId/>
						<PartyAddressName/>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry>DE</PartyAddressCountry>
						<PartyAddressZipcode>67056</PartyAddressZipcode>
						<PartyAddressCity>LUDWIGSHAFEN</PartyAddressCity>
						<PartyContactTelephone/>
						<PartyContactFax/>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:text>OS|POLYTRA NV AS AGENT OF BASF SE&#xD;67056 LUDWIGSHAFEN&#xD;GERMANY</xsl:text>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="DO">
						<PartyDescription>ECU-LINE (PORT KELANG) SDN. B.H.D.</PartyDescription>
						<PartyId/>
						<PartyAddressName>704,BLOCK A, KELANA BUSINESS CENTRE/97, JALAN SS7//2,KELANA JAYA</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry>MY</PartyAddressCountry>
						<PartyAddressZipcode>47301</PartyAddressZipcode>
						<PartyAddressCity>PETALING JAYA</PartyAddressCity>
						<PartyContactTelephone>00 60 3 76 62 7288</PartyContactTelephone>
						<PartyContactFax>00 60 376627587</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'DO|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="N1">
						<PartyDescription>ECU-LINE (PORT KELANG) SDN. B.H.D.</PartyDescription>
						<PartyId/>
						<PartyAddressName>704,BLOCK A, KELANA BUSINESS CENTRE/97, JALAN SS7//2,KELANA JAYA</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry>MY</PartyAddressCountry>
						<PartyAddressZipcode>47301</PartyAddressZipcode>
						<PartyAddressCity>PETALING JAYA</PartyAddressCity>
						<PartyContactTelephone>00 60 3 76 62 7288</PartyContactTelephone>
						<PartyContactFax>00 60 376627587</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'N1|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
				</xsl:when>
				<xsl:when test="$portOfDischarge = 'BDCGP'">
					<Party Type="OS">
						<PartyDescription>ECU WORLDWIDE BELGIUM N.V.</PartyDescription>
						<PartyId/>
						<PartyAddressName>Schomhoeveweg 15</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode>2030</PartyAddressZipcode>
						<PartyAddressCity>Antwerp</PartyAddressCity>
						<PartyContactTelephone>0032 3 541 24 66</PartyContactTelephone>
						<PartyContactFax>As agents only</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:text>OS|ECU-Line n.v.&#xD;Schomhoeveweg 15&#xD;2030 Antwerp&#xD;Tel: 0032 3 541 24 66&#xD;As agents only</xsl:text>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="DO">
						<PartyDescription>ECU LINE (BD.) LIMITED</PartyDescription>
						<PartyId/>
						<PartyAddressName>Akhtaruzzaman Center/(6th  Floor),21//22 Agrabad C//A/Chattogram-4100, Bangladesh/AIN# :101080062</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode/>
						<PartyAddressCity/>
						<PartyContactTelephone>02 333312026-8 EXT:105</PartyContactTelephone>
						<PartyContactFax/>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'DO|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="N1">
						<PartyDescription>ECU LINE (BD.) LIMITED</PartyDescription>
						<PartyId/>
						<PartyAddressName>Akhtaruzzaman Center/(6th  Floor),21//22 Agrabad C//A/Chattogram-4100, Bangladesh/AIN# :101080062</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode/>
						<PartyAddressCity/>
						<PartyContactTelephone>02 333312026-8 EXT:105</PartyContactTelephone>
						<PartyContactFax/>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'N1|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
				</xsl:when>
				<xsl:when test="$portOfDischarge = 'PKKHI'">
					<Party Type="OS">
						<PartyDescription>POLYTRA NV AS AGENT OF BASF SE</PartyDescription>
						<PartyId/>
						<PartyAddressName/>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry>DE</PartyAddressCountry>
						<PartyAddressZipcode>67056</PartyAddressZipcode>
						<PartyAddressCity>LUDWIGSHAFEN</PartyAddressCity>
						<PartyContactTelephone/>
						<PartyContactFax/>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:text>OS|POLYTRA NV AS AGENT OF BASF SE&#xD;67056 LUDWIGSHAFEN&#xD;GERMANY</xsl:text>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="DO">
						<PartyDescription>Transfreight Corporation Pvt Ltd.</PartyDescription>
						<PartyId/>
						<PartyAddressName>3-R, 3rd Floor, Bahria Complex III,/Lalazar, M.T.Khan Road, Karachi./Pakistan.</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode/>
						<PartyAddressCity/>
						<PartyContactTelephone/>
						<PartyContactFax/>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'DO|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="N1">
						<PartyDescription>ECU WORLDWIDE (PVT) LTD.</PartyDescription>
						<PartyId/>
						<PartyAddressName>3-F, 3RD FLOOR, BAHRIA COMPLEX/III, LALAZAR, M.T. KHAN ROAD,/KARACHI - PAKISTAN</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode/>
						<PartyAddressCity/>
						<PartyContactTelephone>00 92 21 35642740-9</PartyContactTelephone>
						<PartyContactFax>00 92 21 35642750</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'N1|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
				</xsl:when>
				<xsl:when test="$portOfDischarge = 'THLCH'">
					<Party Type="OS">
						<PartyDescription>POLYTRA NV AS AGENT OF BASF SE</PartyDescription>
						<PartyId/>
						<PartyAddressName/>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry>DE</PartyAddressCountry>
						<PartyAddressZipcode>67056</PartyAddressZipcode>
						<PartyAddressCity>LUDWIGSHAFEN</PartyAddressCity>
						<PartyContactTelephone/>
						<PartyContactFax/>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:text>OS|POLYTRA NV AS AGENT OF BASF SE&#xD;67056 LUDWIGSHAFEN&#xD;GERMANY</xsl:text>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="DO">
						<PartyDescription>ECU WORLDWIDE (THAILAND) CO., LTD.</PartyDescription>
						<PartyId/>
						<PartyAddressName>628, 5 TH FLOOR TRIPLE I BUILDING/SOI KLAB CHOM, NONSEE ROAD/CHONGNONSEE, YANNAWA,</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry>TH</PartyAddressCountry>
						<PartyAddressZipcode>10120</PartyAddressZipcode>
						<PartyAddressCity>BANGKOK</PartyAddressCity>
						<PartyContactTelephone>00 66 2/6818555</PartyContactTelephone>
						<PartyContactFax>00 66 2/6818262-5</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'DO|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="N1">
						<PartyDescription>ECU WORLDWIDE (THAILAND) CO., LTD.</PartyDescription>
						<PartyId/>
						<PartyAddressName>628, 5 TH FLOOR TRIPLE I BUILDING/SOI KLAB CHOM, NONSEE ROAD/CHONGNONSEE, YANNAWA,</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry>TH</PartyAddressCountry>
						<PartyAddressZipcode>10120</PartyAddressZipcode>
						<PartyAddressCity>BANGKOK</PartyAddressCity>
						<PartyContactTelephone>00 66 2/6818555</PartyContactTelephone>
						<PartyContactFax>00 66 2/6818262-5</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'N1|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
				</xsl:when>
				<xsl:when test="$portOfDischarge = 'NZAKL'">
					<Party Type="OS">
						<PartyDescription>POLYTRA NV AS AGENT OF BASF SE</PartyDescription>
						<PartyId/>
						<PartyAddressName/>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry>DE</PartyAddressCountry>
						<PartyAddressZipcode>67056</PartyAddressZipcode>
						<PartyAddressCity>LUDWIGSHAFEN</PartyAddressCity>
						<PartyContactTelephone/>
						<PartyContactFax/>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:text>OS|POLYTRA NV AS AGENT OF BASF SE&#xD;67056 LUDWIGSHAFEN&#xD;GERMANY</xsl:text>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="DO">
						<PartyDescription>ECU WORLDWIDE NEW ZEALAND LTD.</PartyDescription>
						<PartyId/>
						<PartyAddressName>UNIT 1/203 KIRKBRIDE ROAD/MANGERE, AUCKLAND/NEW ZEALAND</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode/>
						<PartyAddressCity/>
						<PartyContactTelephone>00 64 9 255 0299</PartyContactTelephone>
						<PartyContactFax>00 64 92555338</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'DO|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="N1">
						<PartyDescription>ECU WORLDWIDE NEW ZEALAND LTD.</PartyDescription>
						<PartyId/>
						<PartyAddressName>UNIT 1/203 KIRKBRIDE ROAD/MANGERE, AUCKLAND/NEW ZEALAND</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode/>
						<PartyAddressCity/>
						<PartyContactTelephone>00 64 9 255 0299</PartyContactTelephone>
						<PartyContactFax>00 64 92555338</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'N1|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
				</xsl:when>
				<xsl:when test="$portOfDischarge = 'INMAA'">
					<Party Type="OS">
						<PartyDescription>POLYTRA NV AS AGENT OF BASF SE</PartyDescription>
						<PartyId/>
						<PartyAddressName/>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry>DE</PartyAddressCountry>
						<PartyAddressZipcode>67056</PartyAddressZipcode>
						<PartyAddressCity>LUDWIGSHAFEN</PartyAddressCity>
						<PartyContactTelephone/>
						<PartyContactFax/>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:text>OS|POLYTRA NV AS AGENT OF BASF SE&#xD;67056 LUDWIGSHAFEN&#xD;GERMANY</xsl:text>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="DO">
						<PartyDescription>ALLCARGO LOGISTICS LTD.</PartyDescription>
						<PartyId/>
						<PartyAddressName>2nd FLOOR,LEELAVATHI BUILDING/69 , ARMENIAN STREET, PARYS/600 001 CHENNAI - TAMILNADU/INDIA</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode/>
						<PartyAddressCity/>
						<PartyContactTelephone>00 91 44 4322 9991</PartyContactTelephone>
						<PartyContactFax>00 91 44 4313 8520</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'DO|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="N1">
						<PartyDescription>ALLCARGO LOGISTICS LTD.</PartyDescription>
						<PartyId/>
						<PartyAddressName>2nd FLOOR,LEELAVATHI BUILDING/69 , ARMENIAN STREET, PARYS/600 001 CHENNAI - TAMILNADU/INDIA</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode/>
						<PartyAddressCity/>
						<PartyContactTelephone>00 91 44 4322 9991</PartyContactTelephone>
						<PartyContactFax>00 91 44 4313 8520</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'N1|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
				</xsl:when>
				<xsl:when test="$portOfDischarge = 'AUMEL'">
					<Party Type="OS">
						<PartyDescription>POLYTRA NV AS AGENT OF BASF SE</PartyDescription>
						<PartyId/>
						<PartyAddressName/>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry>DE</PartyAddressCountry>
						<PartyAddressZipcode>67056</PartyAddressZipcode>
						<PartyAddressCity>LUDWIGSHAFEN</PartyAddressCity>
						<PartyContactTelephone/>
						<PartyContactFax/>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:text>OS|POLYTRA NV AS AGENT OF BASF SE&#xD;67056 LUDWIGSHAFEN&#xD;GERMANY</xsl:text>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="DO">
						<PartyDescription>ECU WORLDWIDE AUSTRALIA PTY. LTD.</PartyDescription>
						<PartyId/>
						<PartyAddressName>SUITE 2/35-37 TULLAMARINE PARK ROAD/PO BOX 252/TULLAMARINE/3043 VIC MELBOURNE/AUSTRALIA</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode/>
						<PartyAddressCity/>
						<PartyContactTelephone>00 61 3 8336 8600</PartyContactTelephone>
						<PartyContactFax>00 61 3 9330 0513</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'DO|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="N1">
						<PartyDescription>ECU WORLDWIDE AUSTRALIA PTY. LTD.</PartyDescription>
						<PartyId/>
						<PartyAddressName>SUITE 2/35-37 TULLAMARINE PARK ROAD/PO BOX 252/TULLAMARINE/3043 VIC MELBOURNE/AUSTRALIA</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode/>
						<PartyAddressCity/>
						<PartyContactTelephone>00 61 3 8336 8600</PartyContactTelephone>
						<PartyContactFax>00 61 3 9330 0513</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'N1|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
				</xsl:when>
				<xsl:when test="$portOfDischarge = 'TWKEL'">
					<Party Type="OS">
						<PartyDescription>POLYTRA NV AS AGENT OF BASF SE</PartyDescription>
						<PartyId/>
						<PartyAddressName/>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry>DE</PartyAddressCountry>
						<PartyAddressZipcode>67056</PartyAddressZipcode>
						<PartyAddressCity>LUDWIGSHAFEN</PartyAddressCity>
						<PartyContactTelephone/>
						<PartyContactFax/>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:text>OS|POLYTRA NV AS AGENT OF BASF SE&#xD;67056 LUDWIGSHAFEN&#xD;GERMANY</xsl:text>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="DO">
						<PartyDescription>ORIENTAL POWER LOGISTICS CO., LTD.</PartyDescription>
						<PartyId/>
						<PartyAddressName>19 F,No.88,Sec.2,Nanking E.Road/104 TAIPEI/TAIWAN</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode/>
						<PartyAddressCity/>
						<PartyContactTelephone>00 886 2 2523 5168</PartyContactTelephone>
						<PartyContactFax>00 886 2 2561 8021</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'DO|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="N1">
						<PartyDescription>ORIENTAL POWER LOGISTICS CO., LTD.</PartyDescription>
						<PartyId/>
						<PartyAddressName>19 F,No.88,Sec.2,Nanking E.Road/104 TAIPEI/TAIWAN</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode/>
						<PartyAddressCity/>
						<PartyContactTelephone>00 886 2 2523 5168</PartyContactTelephone>
						<PartyContactFax>00 886 2 2561 8021</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'N1|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
				</xsl:when>
				<xsl:when test="$portOfDischarge = 'MYPKG'">
					<Party Type="OS">
						<PartyDescription>POLYTRA NV AS AGENT OF BASF SE</PartyDescription>
						<PartyId/>
						<PartyAddressName/>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry>DE</PartyAddressCountry>
						<PartyAddressZipcode>67056</PartyAddressZipcode>
						<PartyAddressCity>LUDWIGSHAFEN</PartyAddressCity>
						<PartyContactTelephone/>
						<PartyContactFax/>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:text>OS|POLYTRA NV AS AGENT OF BASF SE&#xD;67056 LUDWIGSHAFEN&#xD;GERMANY</xsl:text>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="DO">
						<PartyDescription>ECU-LINE MALAYSIA SDN. B.H.D.</PartyDescription>
						<PartyId/>
						<PartyAddressName>BBT ONE TOWERS B-2-2, 2ND FLOOR/LORONG BATU NILAM, 1A/BANDAR BUKIT TINGI/41200 KLANG/MALAYSIA</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode/>
						<PartyAddressCity/>
						<PartyContactTelephone>00 60 12.700.8332</PartyContactTelephone>
						<PartyContactFax>00 60</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'DO|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="N1">
						<PartyDescription>ECU-LINE MALAYSIA SDN. B.H.D.</PartyDescription>
						<PartyId/>
						<PartyAddressName>BBT ONE TOWERS B-2-2, 2ND FLOOR/LORONG BATU NILAM, 1A/BANDAR BUKIT TINGI/41200 KLANG/MALAYSIA</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode/>
						<PartyAddressCity/>
						<PartyContactTelephone>00 60 12.700.8332</PartyContactTelephone>
						<PartyContactFax>00 60</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'N1|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
				</xsl:when>
				<xsl:when test="$portOfDischarge = 'NZTRG'">
					<Party Type="OS">
						<PartyDescription>POLYTRA NV AS AGENT OF BASF SE</PartyDescription>
						<PartyId/>
						<PartyAddressName/>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry>DE</PartyAddressCountry>
						<PartyAddressZipcode>67056</PartyAddressZipcode>
						<PartyAddressCity>LUDWIGSHAFEN</PartyAddressCity>
						<PartyContactTelephone/>
						<PartyContactFax/>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:text>OS|POLYTRA NV AS AGENT OF BASF SE&#xD;67056 LUDWIGSHAFEN&#xD;GERMANY</xsl:text>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="DO">
						<PartyDescription>ECULINE NEW ZEALAND LTD.</PartyDescription>
						<PartyId/>
						<PartyAddressName>UNIT 1/203 KIRKBRIDE ROAD/. MANGERE, AUCKLAND/NEW ZEALAND</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode/>
						<PartyAddressCity/>
						<PartyContactTelephone>00 64 9 255 0299</PartyContactTelephone>
						<PartyContactFax>00 64 92555338</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'DO|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="N1">
						<PartyDescription>ECULINE NEW ZEALAND LTD.</PartyDescription>
						<PartyId/>
						<PartyAddressName>UNIT 1/203 KIRKBRIDE ROAD/. MANGERE, AUCKLAND/NEW ZEALAND</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode/>
						<PartyAddressCity/>
						<PartyContactTelephone>00 64 9 255 0299</PartyContactTelephone>
						<PartyContactFax>00 64 92555338</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'N1|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
				</xsl:when>
				<xsl:when test="$portOfDischarge = 'BRRIG'">
					<Party Type="OS">
						<PartyDescription>ECU WORLDWIDE BELGIUM N.V.</PartyDescription>
						<PartyId/>
						<PartyAddressName>Schomhoeveweg 15</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode>2030</PartyAddressZipcode>
						<PartyAddressCity>Antwerp</PartyAddressCity>
						<PartyContactTelephone>0032 3 541 24 66</PartyContactTelephone>
						<PartyContactFax>As agents only</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:text>OS|ECU-Line n.v.&#xD;Schomhoeveweg 15&#xD;2030 Antwerp&#xD;Tel: 0032 3 541 24 66&#xD;As agents only</xsl:text>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="DO">
						<PartyDescription>ECU WORLDWIDE LOGISTICS</PartyDescription>
						<PartyId/>
						<PartyAddressName>DO BRASIL LTDA/CNPJ 05.221.721//0001-45/BELA CINTRA 986, 8°ANDAR CJ 83/BARRIO: CONSOLACAO/01415-906 SAO PAULO/BRAZIL</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode/>
						<PartyAddressCity/>
						<PartyContactTelephone>00 55 11 25968100</PartyContactTelephone>
						<PartyContactFax>00 55 11 25968199</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'DO|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="N1">
						<PartyDescription>ECU WORLDWIDE LOGISTICS</PartyDescription>
						<PartyId/>
						<PartyAddressName>DO BRASIL LTDA/CNPJ 05.221.721//0001-45/BELA CINTRA 986, 8°ANDAR CJ 83/BARRIO: CONSOLACAO/01415-906 SAO PAULO/BRAZIL</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode/>
						<PartyAddressCity/>
						<PartyContactTelephone>00 55 11 25968100</PartyContactTelephone>
						<PartyContactFax>00 55 11 25968199</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'N1|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
				</xsl:when>
				<xsl:when test="$portOfDischarge = 'HKHKG'">
					<Party Type="OS">
						<PartyDescription>POLYTRA NV AS AGENT OF BASF SE</PartyDescription>
						<PartyId/>
						<PartyAddressName/>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry>DE</PartyAddressCountry>
						<PartyAddressZipcode>67056</PartyAddressZipcode>
						<PartyAddressCity>LUDWIGSHAFEN</PartyAddressCity>
						<PartyContactTelephone/>
						<PartyContactFax/>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:text>OS|POLYTRA NV AS AGENT OF BASF SE&#xD;67056 LUDWIGSHAFEN&#xD;GERMANY</xsl:text>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="DO">
						<PartyDescription>ECU WORLDWIDE (HONG KONG) LTD</PartyDescription>
						<PartyId/>
						<PartyAddressName>10TH FLOOR, FORTIS TOWER/77-79 GLOUCESTER ROAD/WAN CHAI/HONG KONG</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode/>
						<PartyAddressCity/>
						<PartyContactTelephone>00 852 34205007</PartyContactTelephone>
						<PartyContactFax>00 852 28651962/21379565</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'DO|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="N1">
						<PartyDescription>ECU WORLDWIDE (HONG KONG) LTD</PartyDescription>
						<PartyId/>
						<PartyAddressName>10TH FLOOR, FORTIS TOWER/77-79 GLOUCESTER ROAD/WAN CHAI/HONG KONG</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode/>
						<PartyAddressCity/>
						<PartyContactTelephone>00 852 34205007</PartyContactTelephone>
						<PartyContactFax>00 852 28651962/21379565</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'N1|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
				</xsl:when>
				<xsl:when test="$portOfDischarge = 'INVTZ'">
					<Party Type="OS">
						<PartyDescription>POLYTRA NV AS AGENT OF BASF SE</PartyDescription>
						<PartyId/>
						<PartyAddressName/>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry>DE</PartyAddressCountry>
						<PartyAddressZipcode>67056</PartyAddressZipcode>
						<PartyAddressCity>LUDWIGSHAFEN</PartyAddressCity>
						<PartyContactTelephone/>
						<PartyContactFax/>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:text>OS|POLYTRA NV AS AGENT OF BASF SE&#xD;67056 LUDWIGSHAFEN&#xD;GERMANY</xsl:text>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="DO">
						<PartyDescription>ALLCARGO LOGISTICS LTD</PartyDescription>
						<PartyId/>
						<PartyAddressName>ASHOKA MY HOME CHAMBERS/2ND FLOOR, #201/S.P. ROAD, SECUNDERABAD 500 003/INDIA</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode/>
						<PartyAddressCity/>
						<PartyContactTelephone>+91 40 40035961 / 963</PartyContactTelephone>
						<PartyContactFax>+91 40 40035962</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'DO|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="N1">
						<PartyDescription>ALLCARGO LOGISTICS LTD</PartyDescription>
						<PartyId/>
						<PartyAddressName>ASHOKA MY HOME CHAMBERS/2ND FLOOR, #201/S.P. ROAD, SECUNDERABAD 500 003/INDIA</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode/>
						<PartyAddressCity/>
						<PartyContactTelephone>+91 40 40035961 / 963</PartyContactTelephone>
						<PartyContactFax>+91 40 40035962</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'N1|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
				</xsl:when>
				<xsl:when test="$portOfDischarge = 'UYMVD'">
					<Party Type="OS">
						<PartyDescription>POLYTRA NV AS AGENT OF BASF SE</PartyDescription>
						<PartyId/>
						<PartyAddressName/>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry>DE</PartyAddressCountry>
						<PartyAddressZipcode>67056</PartyAddressZipcode>
						<PartyAddressCity>LUDWIGSHAFEN</PartyAddressCity>
						<PartyContactTelephone/>
						<PartyContactFax/>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:text>OS|POLYTRA NV AS AGENT OF BASF SE&#xD;67056 LUDWIGSHAFEN&#xD;GERMANY</xsl:text>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="DO">
						<PartyDescription>ECU-LINE URUGUAY</PartyDescription>
						<PartyId/>
						<PartyAddressName>RUT 21 114 130 0017/ZABALA 1542-PISO 2,OFICINA 201/11000 MONTEVIDEO/URUGUAY</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode/>
						<PartyAddressCity/>
						<PartyContactTelephone>00 598 2.917.06.03</PartyContactTelephone>
						<PartyContactFax>00 598 2.917 06 04</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'DO|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="N1">
						<PartyDescription>ECU-LINE URUGUAY</PartyDescription>
						<PartyId/>
						<PartyAddressName>RUT 21 114 130 0017/ZABALA 1542-PISO 2,OFICINA 201/11000 MONTEVIDEO/URUGUAY</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode/>
						<PartyAddressCity/>
						<PartyContactTelephone>00 598 2.917.06.03</PartyContactTelephone>
						<PartyContactFax>00 598 2.917 06 04</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'N1|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
				</xsl:when>
				<xsl:when test="$portOfDischarge = 'MXVER'">
					<Party Type="OS">
						<PartyDescription>POLYTRA NV AS AGENT OF BASF SE</PartyDescription>
						<PartyId/>
						<PartyAddressName/>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry>DE</PartyAddressCountry>
						<PartyAddressZipcode>67056</PartyAddressZipcode>
						<PartyAddressCity>LUDWIGSHAFEN</PartyAddressCity>
						<PartyContactTelephone/>
						<PartyContactFax/>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:text>OS|POLYTRA NV AS AGENT OF BASF SE&#xD;67056 LUDWIGSHAFEN&#xD;GERMANY</xsl:text>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="DO">
						<PartyDescription>ECU WORLDWIDE DE MEXICO SA DE CV</PartyDescription>
						<PartyId/>
						<PartyAddressName>RFC : ELM071127GC8/AV. INSURGENTES SUR NO 716/PISO 3, COLONIA DEL VALLE/DELEGACION BENITO JUAREZ/CP - 03100 CUIDAD DE MEXICO/MEXICO</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode/>
						<PartyAddressCity/>
						<PartyContactTelephone>00 52 555 340 0770</PartyContactTelephone>
						<PartyContactFax>00 52 55 11078185</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'DO|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="N1">
						<PartyDescription>ECU WORLDWIDE DE MEXICO SA DE CV</PartyDescription>
						<PartyId/>
						<PartyAddressName>RFC : ELM071127GC8/AV. INSURGENTES SUR NO 716/PISO 3, COLONIA DEL VALLE/DELEGACION BENITO JUAREZ/CP - 03100 CUIDAD DE MEXICO/MEXICO</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode/>
						<PartyAddressCity/>
						<PartyContactTelephone>00 52 555 340 0770</PartyContactTelephone>
						<PartyContactFax>00 52 55 11078185</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'N1|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
				</xsl:when>
				<xsl:when test="$portOfDischarge = 'AUSYD'">
					<Party Type="OS">
						<PartyDescription>POLYTRA NV AS AGENT OF BASF SE</PartyDescription>
						<PartyId/>
						<PartyAddressName/>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry>DE</PartyAddressCountry>
						<PartyAddressZipcode>67056</PartyAddressZipcode>
						<PartyAddressCity>LUDWIGSHAFEN</PartyAddressCity>
						<PartyContactTelephone/>
						<PartyContactFax/>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:text>OS|POLYTRA NV AS AGENT OF BASF SE&#xD;67056 LUDWIGSHAFEN&#xD;GERMANY</xsl:text>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="DO">
						<PartyDescription>ECU WORLDWIDE AUSTRALIE PTY LTD</PartyDescription>
						<PartyId/>
						<PartyAddressName>SUITE 2/35-37 TULLAMARINE PARK ROAD/PO BOX 252/TULLAMARINE/3043 VIC MELBOURNE/AUSTRALIA</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode/>
						<PartyAddressCity/>
						<PartyContactTelephone>00 61 3 8336 8600</PartyContactTelephone>
						<PartyContactFax>00 61 3 9330 0513</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'DO|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="N1">
						<PartyDescription>ECU WORLDWIDE AUSTRALIE PTY LTD</PartyDescription>
						<PartyId/>
						<PartyAddressName>SUITE 2/35-37 TULLAMARINE PARK ROAD/PO BOX 252/TULLAMARINE/3043 VIC MELBOURNE/AUSTRALIA</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode/>
						<PartyAddressCity/>
						<PartyContactTelephone>00 61 3 8336 8600</PartyContactTelephone>
						<PartyContactFax>00 61 3 9330 0513</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'N1|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
				</xsl:when>
				<xsl:when test="$portOfDischarge = 'VNCLI'">
					<Party Type="OS">
						<PartyDescription>POLYTRA NV AS AGENT OF BASF SE</PartyDescription>
						<PartyId/>
						<PartyAddressName/>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry>DE</PartyAddressCountry>
						<PartyAddressZipcode>67056</PartyAddressZipcode>
						<PartyAddressCity>LUDWIGSHAFEN</PartyAddressCity>
						<PartyContactTelephone/>
						<PartyContactFax/>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:text>OS|POLYTRA NV AS AGENT OF BASF SE&#xD;67056 LUDWIGSHAFEN&#xD;GERMANY</xsl:text>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="DO">
						<PartyDescription>ECU LINE VIETNAM CO.LTD</PartyDescription>
						<PartyId/>
						<PartyAddressName>23 STREET 8A/NAM LONG RESIDENTIAL AREA/TAN THUAN DONG WARD, DISTRICT 7/. HOCHIMINH CITY/VIETNAM</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode/>
						<PartyAddressCity/>
						<PartyContactTelephone>00 84 837733737</PartyContactTelephone>
						<PartyContactFax>00 84 837734506</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'DO|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="N1">
						<PartyDescription>ECU LINE VIETNAM CO.LTD</PartyDescription>
						<PartyId/>
						<PartyAddressName>23 STREET 8A/NAM LONG RESIDENTIAL AREA/TAN THUAN DONG WARD, DISTRICT 7/. HOCHIMINH CITY/VIETNAM</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode/>
						<PartyAddressCity/>
						<PartyContactTelephone>00 84 837733737</PartyContactTelephone>
						<PartyContactFax>00 84 837734506</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'N1|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
				</xsl:when>
				<xsl:when test="$portOfDischarge = 'ILASH'">
					<Party Type="OS">
						<PartyDescription>POLYTRA NV AS AGENT OF BASF SE</PartyDescription>
						<PartyId/>
						<PartyAddressName/>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry>DE</PartyAddressCountry>
						<PartyAddressZipcode>67056</PartyAddressZipcode>
						<PartyAddressCity>LUDWIGSHAFEN</PartyAddressCity>
						<PartyContactTelephone/>
						<PartyContactFax/>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:text>OS|POLYTRA NV AS AGENT OF BASF SE&#xD;67056 LUDWIGSHAFEN&#xD;GERMANY</xsl:text>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="DO">
						<PartyDescription>OSHFIR CUSTOMS &amp; FORWARDING AGENCY</PartyDescription>
						<PartyId/>
						<PartyAddressName>IMPORT &amp; EXPORT LTD./PAL-YAM STREET 5/33095 HAIFA/ISRAEL</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode/>
						<PartyAddressCity/>
						<PartyContactTelephone>00 972 4/867.22.70</PartyContactTelephone>
						<PartyContactFax>00 972 4/864 22 10</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'DO|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="N1">
						<PartyDescription>OSHFIR CUSTOMS &amp; FORWARDING AGENCY</PartyDescription>
						<PartyId/>
						<PartyAddressName>IMPORT &amp; EXPORT LTD./PAL-YAM STREET 5/33095 HAIFA/ISRAEL</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode/>
						<PartyAddressCity/>
						<PartyContactTelephone>00 972 4/867.22.70</PartyContactTelephone>
						<PartyContactFax>00 972 4/864 22 10</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'N1|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
				</xsl:when>
				<xsl:when test="$portOfDischarge = 'INMUN'">
					<Party Type="OS">
						<PartyDescription>POLYTRA NV AS AGENT OF BASF SE</PartyDescription>
						<PartyId/>
						<PartyAddressName/>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry>DE</PartyAddressCountry>
						<PartyAddressZipcode>67056</PartyAddressZipcode>
						<PartyAddressCity>LUDWIGSHAFEN</PartyAddressCity>
						<PartyContactTelephone/>
						<PartyContactFax/>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:text>OS|POLYTRA NV AS AGENT OF BASF SE&#xD;67056 LUDWIGSHAFEN&#xD;GERMANY</xsl:text>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="DO">
						<PartyDescription>ALLCARGO LOGISTICS LIMITED</PartyDescription>
						<PartyId/>
						<PartyAddressName>"SHIV HOUSE", 1ST FLOOR,/PLOT NO: 84, SECTOR - 1/A,/NEAR SHAH HOSPITAL,/GANDHIDHAM - 370201/KUTCH, GUJARAT, INDIA./TEL: +91 2836 233 6679/EMAIL: agl.kandla@allcargologistics.com/CTC: Ms. MEERA DHAWANI</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode/>
						<PartyAddressCity/>
						<PartyContactTelephone/>
						<PartyContactFax/>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'DO|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="N1">
						<PartyDescription>ALLCARGO LOGISTICS LIMITED</PartyDescription>
						<PartyId/>
						<PartyAddressName>"SHIV HOUSE", 1ST FLOOR,/PLOT NO: 84, SECTOR - 1/A,/NEAR SHAH HOSPITAL,/GANDHIDHAM - 370201/KUTCH, GUJARAT, INDIA./TEL: +91 2836 233 6679/EMAIL: agl.kandla@allcargologistics.com/CTC: Ms. MEERA DHAWANI</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode/>
						<PartyAddressCity/>
						<PartyContactTelephone/>
						<PartyContactFax/>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'N1|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
				</xsl:when>
				<xsl:when test="$portOfDischarge = 'PKBQM'">
					<Party Type="OS">
						<PartyDescription>POLYTRA NV AS AGENT OF BASF SE</PartyDescription>
						<PartyId/>
						<PartyAddressName/>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry>DE</PartyAddressCountry>
						<PartyAddressZipcode>67056</PartyAddressZipcode>
						<PartyAddressCity>LUDWIGSHAFEN</PartyAddressCity>
						<PartyContactTelephone/>
						<PartyContactFax/>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:text>OS|POLYTRA NV AS AGENT OF BASF SE&#xD;67056 LUDWIGSHAFEN&#xD;GERMANY</xsl:text>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="DO">
						<PartyDescription>ECU-LINE PAKISTAN (PVT) LTD.</PartyDescription>
						<PartyId/>
						<PartyAddressName>3-F, 3rd FLOOR, BAHRIA COMPLEX III/M.T. KHAN ROAD, LALAZAR/74000 KARACHI/PAKISTAN</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode/>
						<PartyAddressCity/>
						<PartyContactTelephone>00 92 21356427409</PartyContactTelephone>
						<PartyContactFax>00 92 2135642750</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'DO|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="N1">
						<PartyDescription>ECU-LINE PAKISTAN (PVT) LTD.</PartyDescription>
						<PartyId/>
						<PartyAddressName>3-F, 3rd FLOOR, BAHRIA COMPLEX III/M.T. KHAN ROAD, LALAZAR/74000 KARACHI/PAKISTAN</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode/>
						<PartyAddressCity/>
						<PartyContactTelephone>00 92 21356427409</PartyContactTelephone>
						<PartyContactFax>00 92 2135642750</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'N1|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
				</xsl:when>
				<xsl:when test="$portOfDischarge = 'MYPGU'">
					<Party Type="OS">
						<PartyDescription>POLYTRA NV AS AGENT OF BASF SE</PartyDescription>
						<PartyId/>
						<PartyAddressName/>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry>DE</PartyAddressCountry>
						<PartyAddressZipcode>67056</PartyAddressZipcode>
						<PartyAddressCity>LUDWIGSHAFEN</PartyAddressCity>
						<PartyContactTelephone/>
						<PartyContactFax/>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:text>OS|POLYTRA NV AS AGENT OF BASF SE&#xD;67056 LUDWIGSHAFEN&#xD;GERMANY</xsl:text>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="DO">
						<PartyDescription>ECU WORLDWIDE (MALAYSIA) SDN BHD.</PartyDescription>
						<PartyId/>
						<PartyAddressName>NO. 40 A&amp;B/JALAN MOLEK 2//2/TAMAN MOLEK/81100 JOHOR BAHRU/MALAYSIA</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode/>
						<PartyAddressCity/>
						<PartyContactTelephone>00 60 7/352.18.18</PartyContactTelephone>
						<PartyContactFax>00 60 7.352.67.62</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'DO|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="N1">
						<PartyDescription>ECU WORLDWIDE (MALAYSIA) SDN BHD.</PartyDescription>
						<PartyId/>
						<PartyAddressName>NO. 40 A&amp;B/JALAN MOLEK 2//2/TAMAN MOLEK/81100 JOHOR BAHRU/MALAYSIA</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode/>
						<PartyAddressCity/>
						<PartyContactTelephone>00 60 7/352.18.18</PartyContactTelephone>
						<PartyContactFax>00 60 7.352.67.62</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'N1|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
				</xsl:when>
				<xsl:when test="$portOfDischarge = 'CLARI'">
					<Party Type="OS">
						<PartyDescription>ECU WORLDWIDE BELGIUM N.V.</PartyDescription>
						<PartyId/>
						<PartyAddressName>Schomhoeveweg 15</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode>2030</PartyAddressZipcode>
						<PartyAddressCity>Antwerp</PartyAddressCity>
						<PartyContactTelephone>0032 3 541 24 66</PartyContactTelephone>
						<PartyContactFax>As agents only</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:text>OS|ECU WORLDWIDE BELGIUM N.V.&#xD;Schomhoeveweg 15&#xD;2030 Antwerp&#xD;Tel: 0032 3 541 24 66&#xD;As agents only</xsl:text>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="DO">
						<PartyDescription>ECU WORLDWIDE (CHILE) S.A.</PartyDescription>
						<PartyId/>
						<PartyAddressName>AMERICO VESPUCIO 80/PISO 8, OFIC. 81 Y 82/- LAS CONDES - SANTIAGO/CHILE</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode/>
						<PartyAddressCity/>
						<PartyContactTelephone>00 56 2/2430.6600</PartyContactTelephone>
						<PartyContactFax>00 56 5623660164</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'DO|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="N1">
						<PartyDescription>ECU WORLDWIDE (CHILE) S.A.</PartyDescription>
						<PartyId/>
						<PartyAddressName>AMERICO VESPUCIO 80/PISO 8, OFIC. 81 Y 82/- LAS CONDES - SANTIAGO/CHILE</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode/>
						<PartyAddressCity/>
						<PartyContactTelephone>00 56 2/2430.6600</PartyContactTelephone>
						<PartyContactFax>00 56 5623660164</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'N1|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
				</xsl:when>
				<xsl:when test="$portOfDischarge = 'JPYOK'">
					<Party Type="OS">
						<PartyDescription>POLYTRA NV AS AGENT OF BASF SE</PartyDescription>
						<PartyId/>
						<PartyAddressName/>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry>DE</PartyAddressCountry>
						<PartyAddressZipcode>67056</PartyAddressZipcode>
						<PartyAddressCity>LUDWIGSHAFEN</PartyAddressCity>
						<PartyContactTelephone/>
						<PartyContactFax/>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:text>OS|POLYTRA NV AS AGENT OF BASF SE&#xD;67056 LUDWIGSHAFEN&#xD;GERMANY</xsl:text>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="DO">
						<PartyDescription>ECU WORLDWIDE (JAPAN) LTD.</PartyDescription>
						<PartyId/>
						<PartyAddressName>6F,GENERAL BUILDING 1-9-6,/NIHONBASHI - HORIDOME - CHO/CHUO - KU/103-0012 TOKYO/JAPAN</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode/>
						<PartyAddressCity/>
						<PartyContactTelephone>00 81 3 5643 3603</PartyContactTelephone>
						<PartyContactFax>00 81 5031531658</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'DO|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="N1">
						<PartyDescription>ECU WORLDWIDE (JAPAN) LTD.</PartyDescription>
						<PartyId/>
						<PartyAddressName>6F,GENERAL BUILDING 1-9-6,/NIHONBASHI - HORIDOME - CHO/CHUO - KU/103-0012 TOKYO/JAPAN</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode/>
						<PartyAddressCity/>
						<PartyContactTelephone>00 81 3 5643 3603</PartyContactTelephone>
						<PartyContactFax>00 81 5031531658</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'N1|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
				</xsl:when>
				<xsl:when test="$portOfDischarge = 'GTGUA'">
					<Party Type="OS">
						<PartyDescription>ECU WORLDWIDE BELGIUM N.V.</PartyDescription>
						<PartyId/>
						<PartyAddressName>Schomhoeveweg 15</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode>2030</PartyAddressZipcode>
						<PartyAddressCity>Antwerp</PartyAddressCity>
						<PartyContactTelephone>0032 3 541 24 66</PartyContactTelephone>
						<PartyContactFax>As agents only</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:text>OS|ECU WORLDWIDE BELGIUM N.V.&#xD;Schomhoeveweg 15&#xD;2030 Antwerp&#xD;Tel: 0032 3 541 24 66&#xD;As agents only</xsl:text>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="DO">
						<PartyDescription>FLAMINGO LINE DE GUATEMALA S.A.</PartyDescription>
						<PartyId/>
						<PartyAddressName>NIT: 794252-4/1 AVENIDA EDIFICIO TORRE VIVA/ 3ER NIVEL/OFICINA 300 10-87 ZONA 10 GUATEMALA/GUATEMALA</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode/>
						<PartyAddressCity/>
						<PartyContactTelephone>00 502 23626297/94</PartyContactTelephone>
						<PartyContactFax>00 502 23607733</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'DO|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="N1">
						<PartyDescription>FLAMINGO LINE DE GUATEMALA S.A.</PartyDescription>
						<PartyId/>
						<PartyAddressName>NIT: 794252-4/1 AVENIDA EDIFICIO TORRE VIVA/ 3ER NIVEL/OFICINA 300 10-87 ZONA 10 GUATEMALA/GUATEMALA</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode/>
						<PartyAddressCity/>
						<PartyContactTelephone>00 502 23626297/94</PartyContactTelephone>
						<PartyContactFax>00 502 23607733</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'DO|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
				</xsl:when>
				<xsl:when test="$portOfDischarge = 'JPUKB'">
					<Party Type="OS">
						<PartyDescription>ECU WORLDWIDE BELGIUM N.V.</PartyDescription>
						<PartyId/>
						<PartyAddressName>Schomhoeveweg 15</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode>2030</PartyAddressZipcode>
						<PartyAddressCity>Antwerp</PartyAddressCity>
						<PartyContactTelephone>0032 3 541 24 66</PartyContactTelephone>
						<PartyContactFax>As agents only</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:text>OS|ECU WORLDWIDE BELGIUM N.V.&#xD;Schomhoeveweg 15&#xD;2030 Antwerp&#xD;Tel: 0032 3 541 24 66&#xD;As agents only</xsl:text>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="DO">
						<PartyDescription>ECU WORLDWIDE (JAPAN) LTD.</PartyDescription>
						<PartyId/>
						<PartyAddressName>6F HONMACHI ALLGO BLDG./4-4-25 HONMACHI/CHUO - KU/541-0054 OSAKA/JAPAN</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode/>
						<PartyAddressCity/>
						<PartyContactTelephone>00 81 6 6120 6266</PartyContactTelephone>
						<PartyContactFax>00 81 05031530980</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'DO|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="N1">
						<PartyDescription>ECU WORLDWIDE (JAPAN) LTD.</PartyDescription>
						<PartyId/>
						<PartyAddressName>6F HONMACHI ALLGO BLDG./4-4-25 HONMACHI/CHUO - KU/541-0054 OSAKA/JAPAN</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode/>
						<PartyAddressCity/>
						<PartyContactTelephone>00 81 6 6120 6266</PartyContactTelephone>
						<PartyContactFax>00 81 05031530980</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'DO|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
				</xsl:when>
				<xsl:when test="$portOfDischarge = 'JPOSA'">
					<Party Type="OS">
						<PartyDescription>ECU WORLDWIDE BELGIUM N.V.</PartyDescription>
						<PartyId/>
						<PartyAddressName>Schomhoeveweg 15</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode>2030</PartyAddressZipcode>
						<PartyAddressCity>Antwerp</PartyAddressCity>
						<PartyContactTelephone>0032 3 541 24 66</PartyContactTelephone>
						<PartyContactFax>As agents only</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:text>OS|ECU WORLDWIDE BELGIUM N.V.&#xD;Schomhoeveweg 15&#xD;2030 Antwerp&#xD;Tel: 0032 3 541 24 66&#xD;As agents only</xsl:text>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="DO">
						<PartyDescription>ECU WORLDWIDE (JAPAN) LTD.</PartyDescription>
						<PartyId/>
						<PartyAddressName>6F HONMACHI ALLGO BLDG./4-4-25 HONMACHI/CHUO - KU/541-0054 OSAKA/JAPAN</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode/>
						<PartyAddressCity/>
						<PartyContactTelephone>00 81 6 6120 6266</PartyContactTelephone>
						<PartyContactFax>00 81 05031530980</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'DO|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="N1">
						<PartyDescription>ECU WORLDWIDE (JAPAN) LTD.</PartyDescription>
						<PartyId/>
						<PartyAddressName>6F HONMACHI ALLGO BLDG./4-4-25 HONMACHI/CHUO - KU/541-0054 OSAKA/JAPAN</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode/>
						<PartyAddressCity/>
						<PartyContactTelephone>00 81 6 6120 6266</PartyContactTelephone>
						<PartyContactFax>00 81 05031530980</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'DO|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
				</xsl:when>
				<xsl:when test="$portOfDischarge = 'BRITJ'">
					<Party Type="OS">
						<PartyDescription>ECU WORLDWIDE BELGIUM N.V.</PartyDescription>
						<PartyId/>
						<PartyAddressName>Schomhoeveweg 15</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode>2030</PartyAddressZipcode>
						<PartyAddressCity>Antwerp</PartyAddressCity>
						<PartyContactTelephone>0032 3 541 24 66</PartyContactTelephone>
						<PartyContactFax>As agents only</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:text>OS|ECU WORLDWIDE BELGIUM N.V.&#xD;Schomhoeveweg 15&#xD;2030 Antwerp&#xD;Tel: 0032 3 541 24 66&#xD;As agents only</xsl:text>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="DO">
						<PartyDescription>ECU WORLDWIDE LOGISTICS</PartyDescription>
						<PartyId/>
						<PartyAddressName>DO BRASIL LTDA/CNPJ 05.221.721//0001-45/BELA CINTRA 986 - 8TH FLOOR/ROOM 83 - CONSOLACAO/BUILDING KACHID SALIBE/01415-906 SAO PAULO  BRAZIL</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode/>
						<PartyAddressCity/>
						<PartyContactTelephone>00 55 11 25968100</PartyContactTelephone>
						<PartyContactFax>00 55 11 25968199</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'DO|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="N1">
						<PartyDescription>ECU WORLDWIDE LOGISTICS</PartyDescription>
						<PartyId/>
						<PartyAddressName>DO BRASIL LTDA/CNPJ 05.221.721//0001-45/BELA CINTRA 986 - 8TH FLOOR/ROOM 83 - CONSOLACAO/BUILDING KACHID SALIBE/01415-906 SAO PAULO  BRAZIL</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode/>
						<PartyAddressCity/>
						<PartyContactTelephone>00 55 11 25968100</PartyContactTelephone>
						<PartyContactFax>00 55 11 25968199</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'N1|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
				</xsl:when>
				<xsl:when test="$portOfDischarge = 'EGPSD'">
					<Party Type="OS">
						<PartyDescription>ECU WORLDWIDE BELGIUM N.V.</PartyDescription>
						<PartyId/>
						<PartyAddressName>Schomhoeveweg 15</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode>2030</PartyAddressZipcode>
						<PartyAddressCity>Antwerp</PartyAddressCity>
						<PartyContactTelephone>0032 3 541 24 66</PartyContactTelephone>
						<PartyContactFax>As agents only</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:text>OS|ECU WORLDWIDE BELGIUM N.V.&#xD;Schomhoeveweg 15&#xD;2030 Antwerp&#xD;Tel: 0032 3 541 24 66&#xD;As agents only</xsl:text>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="DO">
						<PartyDescription>ECU WORLDWIDE EGYPT LTD.</PartyDescription>
						<PartyId/>
						<PartyAddressName>31, OMAR BAKEER ST.,/9TH FLOOR, FLAT 802/HELIOPOLIS - CAIRO EGYPT</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode/>
						<PartyAddressCity/>
						<PartyContactTelephone>00 20 27744904</PartyContactTelephone>
						<PartyContactFax>00 20 27744906</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'DO|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="N1">
						<PartyDescription>ECU WORLDWIDE EGYPT LTD.</PartyDescription>
						<PartyId/>
						<PartyAddressName>31, OMAR BAKEER ST.,/9TH FLOOR, FLAT 802/HELIOPOLIS - CAIRO EGYPT</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode/>
						<PartyAddressCity/>
						<PartyContactTelephone>00 20 27744904</PartyContactTelephone>
						<PartyContactFax>00 20 27744906</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'N1|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
				</xsl:when>
				<xsl:when test="$portOfDischarge = 'GTSTC'">
					<Party Type="OS">
						<PartyDescription>ECU WORLDWIDE BELGIUM N.V.</PartyDescription>
						<PartyId/>
						<PartyAddressName>Schomhoeveweg 15</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode>2030</PartyAddressZipcode>
						<PartyAddressCity>Antwerp</PartyAddressCity>
						<PartyContactTelephone>0032 3 541 24 66</PartyContactTelephone>
						<PartyContactFax>As agents only</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:text>OS|ECU WORLDWIDE BELGIUM N.V.&#xD;Schomhoeveweg 15&#xD;2030 Antwerp&#xD;Tel: 0032 3 541 24 66&#xD;As agents only</xsl:text>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="DO">
						<PartyDescription>FLAMINGO LINE DE GUATEMALA S.A.</PartyDescription>
						<PartyId/>
						<PartyAddressName>NIT: 794252-4/1 AVENIDA EDIFICIO TORRE VIVA 3ER/NIVEL/OFICINA 300 10-87 ZONA 10 GUATEMALA/GUATEMALA</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode/>
						<PartyAddressCity/>
						<PartyContactTelephone>00 502 23626297/94</PartyContactTelephone>
						<PartyContactFax/>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'DO|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="N1">
						<PartyDescription>FLAMINGO LINE DE GUATEMALA S.A.</PartyDescription>
						<PartyId/>
						<PartyAddressName>NIT: 794252-4/1 AVENIDA EDIFICIO TORRE VIVA 3ER/NIVEL/OFICINA 300 10-87 ZONA 10 GUATEMALA/GUATEMALA</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode/>
						<PartyAddressCity/>
						<PartyContactTelephone>00 502 23626297/94</PartyContactTelephone>
						<PartyContactFax/>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'N1|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
				</xsl:when>
				<xsl:when test="$portOfDischarge = 'TWTXG'">
					<Party Type="OS">
						<PartyDescription>POLYTRA NV AS AGENT OF BASF SE</PartyDescription>
						<PartyId/>
						<PartyAddressName/>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry>DE</PartyAddressCountry>
						<PartyAddressZipcode>67056</PartyAddressZipcode>
						<PartyAddressCity>LUDWIGSHAFEN</PartyAddressCity>
						<PartyContactTelephone/>
						<PartyContactFax/>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:text>OS|POLYTRA NV AS AGENT OF BASF SE&#xD;67056 LUDWIGSHAFEN&#xD;GERMANY</xsl:text>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="DO">
						<PartyDescription>ORIENTAL POWER LOGISTICS CO., LTD.</PartyDescription>
						<PartyId/>
						<PartyAddressName>19 F,No.88,Sec.2,Nanking E.Road/104 TAIPEI/TAIWAN</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode/>
						<PartyAddressCity/>
						<PartyContactTelephone>00 886 2 2523 5168</PartyContactTelephone>
						<PartyContactFax>00 886 2 2561 8021</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'DO|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="N1">
						<PartyDescription>ORIENTAL POWER LOGISTICS CO., LTD.</PartyDescription>
						<PartyId/>
						<PartyAddressName>19 F,No.88,Sec.2,Nanking E.Road/104 TAIPEI/TAIWAN</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode/>
						<PartyAddressCity/>
						<PartyContactTelephone>00 886 2 2523 5168</PartyContactTelephone>
						<PartyContactFax>00 886 2 2561 8021</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'N1|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
				</xsl:when>
				<xsl:when test="$portOfDischarge = 'AUBNE'">
					<Party Type="OS">
						<PartyDescription>POLYTRA NV AS AGENT OF BASF SE</PartyDescription>
						<PartyId/>
						<PartyAddressName/>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry>DE</PartyAddressCountry>
						<PartyAddressZipcode>67056</PartyAddressZipcode>
						<PartyAddressCity>LUDWIGSHAFEN</PartyAddressCity>
						<PartyContactTelephone/>
						<PartyContactFax/>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:text>OS|POLYTRA NV AS AGENT OF BASF SE&#xD;67056 LUDWIGSHAFEN&#xD;GERMANY</xsl:text>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="DO">
						<PartyDescription>ECU WORLDWIDE AUSTRALIA PTY. LTD.</PartyDescription>
						<PartyId/>
						<PartyAddressName>SUITE 2/35-37 TULLAMARINE PARK ROAD/PO BOX 252/TULLAMARINE/3043 VIC MELBOURNE/AUSTRALIA</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode/>
						<PartyAddressCity/>
						<PartyContactTelephone>00 61 3 8336 8600</PartyContactTelephone>
						<PartyContactFax>00 61 3 9330 0513</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'DO|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="N1">
						<PartyDescription>ECU WORLDWIDE AUSTRALIA PTY. LTD.</PartyDescription>
						<PartyId/>
						<PartyAddressName>SUITE 2/35-37 TULLAMARINE PARK ROAD/PO BOX 252/TULLAMARINE/3043 VIC MELBOURNE/AUSTRALIA</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode/>
						<PartyAddressCity/>
						<PartyContactTelephone>00 61 3 8336 8600</PartyContactTelephone>
						<PartyContactFax>00 61 3 9330 0513</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'N1|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
				</xsl:when>
				<xsl:when test="$portOfDischarge = 'MYPEN'">
					<Party Type="OS">
						<PartyDescription>POLYTRA NV AS AGENT OF BASF SE</PartyDescription>
						<PartyId/>
						<PartyAddressName/>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry>DE</PartyAddressCountry>
						<PartyAddressZipcode>67056</PartyAddressZipcode>
						<PartyAddressCity>LUDWIGSHAFEN</PartyAddressCity>
						<PartyContactTelephone/>
						<PartyContactFax/>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:text>OS|POLYTRA NV AS AGENT OF BASF SE&#xD;67056 LUDWIGSHAFEN&#xD;GERMANY</xsl:text>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="DO">
						<PartyDescription>ECU WORLDWIDE (MALAYSIA) SDN BHD</PartyDescription>
						<PartyId/>
						<PartyAddressName>PENANG MALAYSIA./1818B  GURNEY TOWER PERSIARAN/GURNEY 10250 PENANGMALAYSIA/PENANG 10250, MALAYSIA</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode/>
						<PartyAddressCity/>
						<PartyContactTelephone/>
						<PartyContactFax/>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'DO|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="N1">
						<PartyDescription>ECU WORLDWIDE (MALAYSIA) SDN BHD</PartyDescription>
						<PartyId/>
						<PartyAddressName>PENANG MALAYSIA./1818B  GURNEY TOWER PERSIARAN/GURNEY 10250 PENANGMALAYSIA/PENANG 10250, MALAYSIA</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode/>
						<PartyAddressCity/>
						<PartyContactTelephone/>
						<PartyContactFax/>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'N1|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
				</xsl:when>
				<xsl:when test="$portOfDischarge = 'CIABJ'">
					<Party Type="OS">
						<PartyDescription>ECU WORLDWIDE BELGIUM N.V.</PartyDescription>
						<PartyId/>
						<PartyAddressName>Schomhoeveweg 15</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode>2030</PartyAddressZipcode>
						<PartyAddressCity>Antwerp</PartyAddressCity>
						<PartyContactTelephone>0032 3 541 24 66</PartyContactTelephone>
						<PartyContactFax>As agents only</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:text>OS|POLYTRA NV AS AGENT OF BASF SE&#xD;67056 LUDWIGSHAFEN&#xD;GERMANY</xsl:text>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="DO">
						<PartyDescription>ECU WORLDWIDE COTE D'IVOIRE SARL</PartyDescription>
						<PartyId/>
						<PartyAddressName>MARCORY ZONE 4/BVD VGE IMMEUBLE PRIVILEGE 2020/3IÈME ETAGE, FACE FEUX TRICOLORES/CAMP COMMANDO/BP 2528 ABIDJAN 18/IVORY COAST</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode/>
						<PartyAddressCity/>
						<PartyContactTelephone>22 5 2125 7179</PartyContactTelephone>
						<PartyContactFax>22 5 2125 6079</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'DO|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="N1">
						<PartyDescription>SAME AS CONSIGNEE</PartyDescription>
						<PartyId/>
						<PartyAddressName/>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode/>
						<PartyAddressCity/>
						<PartyContactTelephone/>
						<PartyContactFax/>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'N1|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
				</xsl:when>
				<xsl:when test="$portOfDischarge = 'JPTYO'">
					<Party Type="OS">
						<PartyDescription>ECU WORLDWIDE BELGIUM N.V.</PartyDescription>
						<PartyId/>
						<PartyAddressName>Schomhoeveweg 15</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode>2030</PartyAddressZipcode>
						<PartyAddressCity>Antwerp</PartyAddressCity>
						<PartyContactTelephone>0032 3 541 24 66</PartyContactTelephone>
						<PartyContactFax>As agents only</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:text>OS|ECU WORLDWIDE BELGIUM N.V.&#xD;Schomhoeveweg 15&#xD;2030 Antwerp&#xD;Tel: 0032 3 541 24 66&#xD;As agents only</xsl:text>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="DO">
						<PartyDescription>ECU WORLDWIDE JAPAN(TOKYO) LTD</PartyDescription>
						<PartyId/>
						<PartyAddressName>6F HORIDOME GENERAL BUILDING 196/NIHONBASHIHORIDOMECHO, CHUOKU/1030012 TOKYO/JAPAN</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode/>
						<PartyAddressCity/>
						<PartyContactTelephone>81 3 5643 3603</PartyContactTelephone>
						<PartyContactFax>81 050-3153-1658</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'DO|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
					<Party Type="N1">
						<PartyDescription>ECU WORLDWIDE JAPAN(TOKYO) LTD</PartyDescription>
						<PartyId/>
						<PartyAddressName>6F HORIDOME GENERAL BUILDING 196/NIHONBASHIHORIDOMECHO, CHUOKU/1030012 TOKYO/JAPAN</PartyAddressName>
						<PartyAddressName1/>
						<PartyAddressName2/>
						<PartyAddressCountry/>
						<PartyAddressZipcode/>
						<PartyAddressCity/>
						<PartyContactTelephone>81 3 5643 3603</PartyContactTelephone>
						<PartyContactFax>81 050-3153-1658</PartyContactFax>
						<PartyLetterOfCredit1/>
						<PartyUdf>
							<Udf>
								<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
								<UdfValue>
									<xsl:value-of select="'N1|BE|'"/>
								</UdfValue>
							</Udf>
						</PartyUdf>
					</Party>
				</xsl:when>
			</xsl:choose>
			<!-- DeletePrevious staat uit om alle parties van de subdossiers te verzamelen hier -->
			<xsl:for-each select="Group11/NAD">
				<xsl:if test="not(E-3035=('DO', 'OS', 'N1', 'N2'))">
					<xsl:call-template name="printAddress">
						<xsl:with-param name="country" select="$portOfDischarge"/>
					</xsl:call-template>
				</xsl:if>
			</xsl:for-each>
			<xsl:for-each select="Group18/Group19/NAD">
				<xsl:if test="not(E-3035=('DO', 'OS', 'N1', 'N2'))">
					<xsl:call-template name="printAddress">
						<xsl:with-param name="country" select="$portOfDischarge"/>
					</xsl:call-template>
				</xsl:if>
			</xsl:for-each>
			<xsl:for-each select="Group37/Group39/NAD">
				<xsl:if test="not(E-3035=('DO', 'OS', 'N1', 'N2'))">
					<xsl:call-template name="printAddress">
						<xsl:with-param name="country" select="$portOfDischarge"/>
					</xsl:call-template>
				</xsl:if>
			</xsl:for-each>
		</FileParties>
		<FileContainers DeletePrevious="Y">
			<xsl:for-each select="Group37">
				<Container>
					<ContContainerNumber>
						<xsl:value-of select="EQD/E-C237/C-8260"/>
					</ContContainerNumber>
					<ContSizeOfContainer>
						<xsl:value-of select="substring(EQD/E-C224/C-8155, 1, 2)"/>
					</ContSizeOfContainer>
					<ContTypeOfContainer>
						<xsl:value-of select="substring(EQD/E-C224/C-8155, 3)"/>
					</ContTypeOfContainer>
					<xsl:for-each select="MEA">
						<xsl:if test="E-6311 = 'WT'">
							<xsl:if test="E-C502/C-6313 = 'AAB'">
								<ContSizeOfContainer>
									<xsl:value-of select="E-C174/C-6314 div 1000"/>
								</ContSizeOfContainer>
							</xsl:if>
							<xsl:if test="E-C502/C-6313 = 'AAE'">
								<ContNettWeight>
									<xsl:value-of select="E-C174/C-6314"/>
								</ContNettWeight>
							</xsl:if>
						</xsl:if>
					</xsl:for-each>
					<ContSeal1>
						<xsl:value-of select="SEL[1]/E-9308"/>
					</ContSeal1>
					<ContSeal2>
						<xsl:value-of select="SEL[2]/E-9308"/>
					</ContSeal2>
					<ContSealNumbers>
						<SealNumber>
							<Seal1>
								<xsl:value-of select="SEL[1]/E-9308"/>
							</Seal1>
							<Seal2>
								<xsl:value-of select="SEL[2]/E-9308"/>
							</Seal2>
						</SealNumber>
					</ContSealNumbers>
					<ContTranshipment>
						<xsl:value-of select="TMD/E-C219/C-8335"/>
					</ContTranshipment>
					<ContainerUdf>
						<xsl:for-each select="MEA[E-C502/C-6154='VGM']">
							<Udf>
								<UdfCode CreateIfNotExists="Y">SOLAS_VW</UdfCode>
								<UdfValue>
									<xsl:value-of select="E-C174/C-6314"/>
								</UdfValue>
							</Udf>
						</xsl:for-each>
						<xsl:for-each select="FTX">
							<xsl:choose>
								<xsl:when test="E-4451='ABL'">
									<xsl:if test="E-C107/C-4441='VGM'">
										<Udf>
											<UdfCode CreateIfNotExists="Y">SOLAS_TX</UdfCode>
											<UdfValue>
												<xsl:value-of select="E-C108/C-4440"/>
											</UdfValue>
										</Udf>
									</xsl:if>
								</xsl:when>
								<xsl:when test="E-4451='ZZZ'">
									<xsl:if test="E-C107/C-4441='VGM'">
										<Udf>
											<UdfCode CreateIfNotExists="Y">SOLAS_MCA</UdfCode>
											<UdfValue>
												<xsl:value-of select="E-C108/C-4440"/>
											</UdfValue>
										</Udf>
									</xsl:if>
								</xsl:when>
							</xsl:choose>
						</xsl:for-each>
					</ContainerUdf>
				</Container>
			</xsl:for-each>
		</FileContainers>
	</xsl:template>
	<xsl:template name="printAddress">
		<xsl:param name="country"/>
		<Party>
			<xsl:variable name="TaxID">
				<xsl:if test="E-C082/C-1131 = '167'">
					<xsl:value-of select="substring-after(E-C082/C-3039,'/')"/>
				</xsl:if>
			</xsl:variable> 
			<xsl:attribute name="Type">
				<xsl:value-of select="E-3035"/>
			</xsl:attribute>
			<PartyDescription>
				<xsl:if test="substring(E-C080/C-3036[1], 1, 12) = 'in your name'">
					<xsl:choose>
						<xsl:when test="//NAD[E-3035='FW']/E-C082/C-3039 = '2683269'">POLYTRA-CONDEMINAS S.L. as agent of</xsl:when>
						<xsl:when test="//NAD[E-3035='FW']/E-C082/C-3039 = '5904903'">Fracht Project Logistics, S.L as agent of</xsl:when>
						<xsl:otherwise>POLYTRA N.V. as agent of BASF</xsl:otherwise>
					</xsl:choose>
				</xsl:if>
				<xsl:if test="not(substring(E-C080/C-3036[1], 1, 12) = 'in your name')">
					<xsl:value-of select="E-C080/C-3036[1]"/>
				</xsl:if>
			</PartyDescription>
			<PartyReference>
				<xsl:if test="E-3035 = 'AM'">
					<xsl:if test="substring(E-C080/C-3036[1], 1, 12) = 'in your name'">
						<xsl:choose>
							<xsl:when test="//NAD[E-3035='FW']/E-C082/C-3039 = '2683269'">POLYTRA-CONDEMINAS S.L. as agent of</xsl:when>
							<xsl:when test="//NAD[E-3035='FW']/E-C082/C-3039 = '5904903'">Fracht Project Logistics, S.L as agent of</xsl:when>
							<xsl:otherwise>POLYTRA N.V. as agent of BASF</xsl:otherwise>
						</xsl:choose>
					</xsl:if>
					<xsl:if test="not(substring(E-C080/C-3036[1], 1, 12) = 'in your name')">
						<xsl:value-of select="E-C080/C-3036[1]"/>
					</xsl:if>
				</xsl:if>
			</PartyReference>
			<xsl:if test="E-3035 = 'CA'">
				<PartyId>
					<xsl:value-of select="concat(E-C082/C-3039, '_CA')"/>
				</PartyId>
			</xsl:if>
			<xsl:if test="E-3035 != 'CA'">
				<PartyId>
					<xsl:if test="E-3035 = 'EP'">
						<xsl:value-of select="concat(E-C082/C-3039, '_EP')"/>
					</xsl:if>
					<xsl:if test="E-3035 != 'EP'">
						<xsl:value-of select="concat(E-C082/C-3039, '_NotCA')"/>
					</xsl:if>
				</PartyId>
			</xsl:if>
			<PartyAddressName>
				<xsl:value-of select="concat(E-C059/C-3042[1], E-C059/C-3042[2], E-C059/C-3042[3], E-C059/C-3042[4])"/>
			</PartyAddressName>
			<PartyAddressName1>
				<xsl:if test="substring(E-C080/C-3036[1], 1, 12) = 'in your name'">
					<xsl:choose>
						<xsl:when test="//NAD[E-3035='FW']/E-C082/C-3039 = '2683269'">POLYTRA-CONDEMINAS S.L. as agent of</xsl:when>
						<xsl:when test="//NAD[E-3035='FW']/E-C082/C-3039 = '5904903'">Fracht Project Logistics, S.L as agent of</xsl:when>
						<xsl:otherwise>POLYTRA N.V. as agent of BASF</xsl:otherwise>
					</xsl:choose>
				</xsl:if>
				<xsl:if test="not(substring(E-C080/C-3036[1], 1, 12) = 'in your name')">
					<xsl:value-of select="E-C080/C-3036[1]"/>
				</xsl:if>
			</PartyAddressName1>
			<PartyAddressName2>
				<xsl:if test="E-C080/C-3036[2] = 'of BASF SE'">BASF SE 67056 Ludwigshafen Germany</xsl:if>
				<xsl:if test="not(E-C080/C-3036[2] = 'of BASF SE')">
					<xsl:value-of select="normalize-space(concat(E-C080/C-3036[2], ' ', E-C080/C-3036[3], ' ', E-C080/C-3036[4], ' '))"/>
				</xsl:if>
			</PartyAddressName2>
			<PartyAddressName3>
				<xsl:choose>
					<xsl:when test="substring($country, 1, 2) = 'BR' or substring($country, 1, 2) = 'BO'">
						<xsl:if test="E-C082/C-3039 and E-C082/C-1131='167'">
							<xsl:text>CNPJ: </xsl:text>
							<xsl:value-of select="E-C082/C-3039"/>
						</xsl:if>
					</xsl:when>
					<xsl:when test="substring($country, 1, 2) = 'CO' or substring($country, 1, 2) = 'GT'">
						<xsl:if test="E-C082/C-3039 and E-C082/C-1131='167'">
							<xsl:text>NIT: </xsl:text>
							<xsl:value-of select="E-C082/C-3039"/>
						</xsl:if>
					</xsl:when>
					<xsl:when test="substring($country, 1, 2) = 'AR'">
						<xsl:if test="E-C082/C-3039 and E-C082/C-1131='167'">
							<xsl:text>CUIT: </xsl:text>
							<xsl:value-of select="E-C082/C-3039"/>
						</xsl:if>
					</xsl:when>
					<xsl:when test="substring($country, 1, 2) = 'MX'">
						<xsl:if test="E-C082/C-3039 and E-C082/C-1131='167'">
							<xsl:text>RFC: </xsl:text>
							<xsl:value-of select="E-C082/C-3039"/>
						</xsl:if>
					</xsl:when>
					<xsl:when test="substring($country, 1, 2) = 'DO'">
						<xsl:if test="E-C082/C-3039 and E-C082/C-1131='167'">
							<xsl:text>RNC: </xsl:text>
							<xsl:value-of select="E-C082/C-3039"/>
						</xsl:if>
					</xsl:when>
					<xsl:when test="substring($country, 1, 2) = 'EC' or substring($country, 1, 2) = 'PE' or substring($country, 1, 2) = 'PY'">
						<xsl:if test="E-C082/C-3039 and E-C082/C-1131='167'">
							<xsl:text>RUC: </xsl:text>
							<xsl:value-of select="E-C082/C-3039"/>
						</xsl:if>
					</xsl:when>
					<xsl:when test="substring($country, 1, 2) = 'VE'">
						<xsl:if test="E-C082/C-3039 and E-C082/C-1131='167'">
							<xsl:text>RIF: </xsl:text>
							<xsl:value-of select="E-C082/C-3039"/>
						</xsl:if>
					</xsl:when>
					<xsl:when test="substring($country, 1, 2) = 'TR'">
						<xsl:if test="$TaxID != ''">
							<xsl:text>TAX ID: </xsl:text>
							<xsl:value-of select="$TaxID"/>
						</xsl:if>
					</xsl:when>
					<xsl:when test="substring($country, 1, 2) = 'ID' or substring($country, 1, 2) = 'VN'">
						<xsl:if test="E-C082/C-3039 and E-C082/C-1131='167'">
							<xsl:text>TAX ID: </xsl:text>
							<xsl:value-of select="E-C082/C-3039"/>
						</xsl:if>
					</xsl:when>
					<xsl:when test="substring($country, 1, 2) = 'UY' or substring($country, 1, 2) = 'CL'">
						<xsl:if test="E-C082/C-3039 and E-C082/C-1131='167'">
							<xsl:text>RUT: </xsl:text>
							<xsl:value-of select="E-C082/C-3039"/>
						</xsl:if>
					</xsl:when>
					<xsl:when test="substring($country, 1, 2) = 'PK'">
						<xsl:if test="E-C082/C-3039 and E-C082/C-1131='167'">
							<xsl:text>NTN: </xsl:text>
							<xsl:value-of select="E-C082/C-3039"/>
						</xsl:if>
					</xsl:when>
					<xsl:when test="substring($country, 1, 2) = 'CN'">
						<xsl:if test="E-C082/C-3039 and E-C082/C-1131='167'">
							<xsl:text>USCI: </xsl:text>
							<xsl:value-of select="E-C082/C-3039"/>
						</xsl:if>
					</xsl:when>
					<xsl:when test="substring($country, 1, 2) = 'DZ'">
						<xsl:if test="E-C082/C-3039 and E-C082/C-1131='167'">
							<xsl:text>NIF: </xsl:text>
							<xsl:value-of select="E-C082/C-3039"/>
						</xsl:if>
					</xsl:when>
				</xsl:choose>
			</PartyAddressName3>
			<PartyAddressCountry>
				<xsl:value-of select="E-3207"/>
			</PartyAddressCountry>
			<PartyAddressZipcode>
				<xsl:value-of select="concat(E-C058/C-3124, ' ',E-3251)"/>
			</PartyAddressZipcode>
			<PartyAddressCity>
				<xsl:value-of select="E-3164, ' ',../LOC[E-3227='47']/E-C517/C-3224"/>
			</PartyAddressCity>
			<xsl:for-each select="../Group12">
				<PartyContactFax>
					<xsl:value-of select="COM/E-C076[C-3155 = 'FX']/C-3148"/>
				</PartyContactFax>
			</xsl:for-each>
			<xsl:for-each select="../LOC[E-3227 = 'ZZZ']">
				<PartyContactFax>
					<xsl:value-of select="E-C519/C-3222[1]"/>
				</PartyContactFax>
				<PartyContactTelephone>
					<xsl:value-of select="E-C517/C-3224[1]"/>
				</PartyContactTelephone>
				<PartyLetterOfCredit1>
					<xsl:value-of select="E-C553/C-3232[1]"/>
				</PartyLetterOfCredit1>
			</xsl:for-each>
			<xsl:if test="E-3035 = 'BL' and ../Group12/COM">
				<PartyLetterOfCredit1>
					<xsl:value-of select="../Group12/COM/E-C076/C-3148"/>
				</PartyLetterOfCredit1>
			</xsl:if>
			<PartyUdf>
				<Udf>
					<UdfCode CreateIfNotExists="Y">PANAME</UdfCode>
					<UdfValue>
						<xsl:choose>
							<xsl:when test="substring(E-C080/C-3036[1], 1, 12) = 'in your name'">
								<xsl:choose>
									<xsl:when test="//NAD[E-3035='FW']/E-C082/C-3039 = '2683269'">OS|POLYTRA-CONDEMINAS S.L. as agent of|BASF SE 67056 Ludwigshafen Germany|</xsl:when>
									<xsl:when test="//NAD[E-3035='FW']/E-C082/C-3039 = '5904903'">OS|Fracht Project Logistics, S.L as agent of|BASF SE 67056 Ludwigshafen Germany|</xsl:when>
									<xsl:when test="substring(E-C080/C-3036[2], 1, 10) = 'of BASF SE'">OS|POLYTRA N.V. as agent of|BASF SE 67056 Ludwigshafen Germany|</xsl:when>
									<xsl:when test="substring(E-C080/C-3036[2], 1, 14) = 'of Styrolution'">OS|POLYTRA N.V. as agent of&#xD;Styrolution GmbH|</xsl:when>
									<xsl:when test="substring(E-C080/C-3036[2], 1, 21) = 'of BASF Polyurethanes'">OS|POLYTRA N.V. as agent of&#xD;BASF Polyurethanes GmbH|</xsl:when>
								</xsl:choose>
							</xsl:when>
							<xsl:when test="E-3035 = 'OS'">
								<xsl:choose>
									<xsl:when test="substring($country, 1, 2) = 'JP'">
										<xsl:choose>
											<xsl:when test="substring(E-C080/C-3036[1], 1, 24) = 'BASF South East Asia Pte'">OS|BASF South East Asia Pte Ltd.&#xD;7 Temasek Boulevard&#xD;35-01 Suntec Tower One&#xD;SGP-Singapore 038987 SG&#xD;Tel: +603 2246 9000</xsl:when>
											<xsl:when test="substring(E-C080/C-3036[1], 1, 26) = 'BASF Colors &amp; Effects GmbH'">OS|BASF Colors &amp; Effects GmbH&#xD;Rheinschanze 1&#xD;67059 Ludwigshafen DE</xsl:when>
											<xsl:when test="substring(E-C080/C-3036[1], 1, 31) = 'BASF Colors &amp; Effects Singapore'">OS|BASF Colors &amp;Effects Singapore Pte&#xD;LTD 7 Temasek Boulevard&#xD;35-01 Suntec Tower One&#xD;SGP-Singapore 038987 SG</xsl:when>
											<xsl:when test="substring(E-C080/C-3036[2], 1, 14) = 'Solutions GmbH'">OS|BASF Construction Solutions GmbH&#xD;Troosstberg, Germany</xsl:when>
											<xsl:when test="substring(E-C080/C-3036[1], 1, 32) = 'BASF Construction Solutions GmbH'">OS|BASF Construction Solutions GmbH&#xD;Dr.-Albert-Frank-Str.32&#xD;83308 Troosstberg Germany</xsl:when>
											<xsl:when test="substring(E-C080/C-3036[2], 1, 19) = 'Calle Can Rabia 3-5'">OS|BASF Espanola S.L.&#xD;Calle Can Rabia 3-5&#xD;08017 Barcelona ES</xsl:when>
											<xsl:when test="substring(E-C080/C-3036[2], 1, 35) = 'Pol. Ind. Can Jardi, Calle Verdi, 3'">OS|BASF Poliuretanooss Iberia S.A.&#xD;Pol. Ind. Can Jardi, Calle Verdi,&#xD;36-38, ES-08191 Rubi (Barcelona)</xsl:when>
											<xsl:when test="substring(E-C080/C-3036[2], 1, 18) = 'Carl-Bosch-Strasse'">OS|BASF SE Carl-Boossch-Strasse 38&#xD;67056 Ludwigshafen DE</xsl:when>
											<xsl:otherwise>
												<xsl:call-template name="getNodeValues"/>
											</xsl:otherwise>
										</xsl:choose>
									</xsl:when>
									<xsl:when test="substring(E-C080/C-3036[1], 1, 24) = 'BASF South East Asia Pte'">OS|BASF South East Asia Pte Ltd.&#xD;7 Temasek Boulevard&#xD;35-01 Suntec Tower One&#xD;SGP-Singapore 038987 SG</xsl:when>
									<xsl:when test="substring(E-C080/C-3036[1], 1, 26) = 'BASF Colors &amp; Effects GmbH'">OS|BASF Colors &amp; Effects GmbH&#xD;Rheinschanze 1&#xD;67059 Ludwigshafen DE</xsl:when>
									<xsl:when test="substring(E-C080/C-3036[1], 1, 31) = 'BASF Colors &amp; Effects Singapore'">OS|BASF Colors &amp;Effects Singapore Pte&#xD;LTD 7 Temasek Boulevard&#xD;35-01 Suntec Tower One&#xD;SGP-Singapore 038987 SG</xsl:when>
									<xsl:when test="substring(E-C080/C-3036[2], 1, 14) = 'Solutions GmbH'">OS|BASF Construction Solutions GmbH&#xD;Troosstberg, Germany</xsl:when>
									<xsl:when test="substring(E-C080/C-3036[1], 1, 32) = 'BASF Construction Solutions GmbH'">OS|BASF Construction Solutions GmbH&#xD;Dr.-Albert-Frank-Str.32&#xD;83308 Troosstberg Germany</xsl:when>
									<xsl:when test="substring(E-C080/C-3036[1], 1, 32) = 'BASF Construction Additives GmbH'">OS|BASF Construction Additives GmbH&#xD;Dr.-Albert-Frank-Str.32&#xD;83308 Troosstberg Germany</xsl:when>
									<xsl:when test="substring(E-C080/C-3036[2], 1, 19) = 'Calle Can Rabia 3-5'">OS|BASF Espanola S.L.&#xD;Calle Can Rabia 3-5&#xD;08017 Barcelona ES</xsl:when>
									<xsl:when test="substring(E-C080/C-3036[2], 1, 35) = 'Pol. Ind. Can Jardi, Calle Verdi, 3'">OS|BASF Poliuretanooss Iberia S.A.&#xD;Pol. Ind. Can Jardi, Calle Verdi,&#xD;36-38, ES-08191 Rubi (Barcelona)</xsl:when>
									<xsl:when test="substring(E-C080/C-3036[2], 1, 18) = 'Carl-Bosch-Strasse'">OS|BASF SE Carl-Boossch-Strasse 38&#xD;67056 Ludwigshafen DE</xsl:when>
									<xsl:otherwise>
										<xsl:call-template name="getNodeValues"/>
									</xsl:otherwise>
								</xsl:choose>
							</xsl:when>
							<xsl:when test="E-3035 = 'N1' or E-3035 = 'DO'">
								<xsl:call-template name="getNodeValuesNADN1"/>
							</xsl:when>
							<xsl:otherwise>
								<xsl:call-template name="getNodeValues"/>
							</xsl:otherwise>
						</xsl:choose>
					</UdfValue>
				</Udf>
				<xsl:if test="E-3035 = 'N1' or E-3035 = 'DO'">
					<Udf>
						<UdfCode>
							<xsl:text>MISSCOD-</xsl:text>
							<xsl:value-of select="E-3035"/>
						</UdfCode>
						<UdfValue>
							<xsl:for-each select="descendant::node()[ancestor-or-self::E-C082 or self::C-3124 and not(@*)]">
								<xsl:value-of select="concat(self::text(),'|')"/>
							</xsl:for-each>
						</UdfValue>
					</Udf>
				</xsl:if>
				<xsl:for-each select="../Group13/DOC">
					<Udf>
						<UdfCode CreateIfNotExists="Y">
							<xsl:value-of select="concat('DOC-',E-C002/C-1001, '-ORIG')"/>
						</UdfCode>
						<UdfValue>
							<xsl:value-of select="E-1218"/>
						</UdfValue>
					</Udf>
					<Udf>
						<UdfCode CreateIfNotExists="Y">
							<xsl:value-of select="concat('DOC-',E-C002/C-1001, '-COPY')"/>
						</UdfCode>
						<UdfValue>
							<xsl:value-of select="E-1220"/>
						</UdfValue>
					</Udf>
					<Udf>
						<UdfCode CreateIfNotExists="Y">
							<xsl:value-of select="concat('DOC-',E-C002/C-1001, '-COM')"/>
						</UdfCode>
						<UdfValue>
							<xsl:value-of select="E-3153"/>
						</UdfValue>
					</Udf>
				</xsl:for-each>
				<xsl:choose>
					<xsl:when test="substring($country, 1, 2) = 'BR'">
						<xsl:if test="E-C082/C-3039">
							<Udf>
								<UdfCode CreateIfNotExists="Y">
									<xsl:text>CNPJ</xsl:text>
								</UdfCode>
								<UdfValue>
									<xsl:value-of select="E-C082/C-3039"/>
								</UdfValue>
							</Udf>
						</xsl:if>
					</xsl:when>
					<xsl:when test="substring($country, 1, 2) = 'CO'">
						<xsl:if test="E-C082/C-3039">
							<Udf>
								<UdfCode CreateIfNotExists="Y">
									<xsl:text>NIT</xsl:text>
								</UdfCode>
								<UdfValue>
									<xsl:value-of select="E-C082/C-3039"/>
								</UdfValue>
							</Udf>
						</xsl:if>
					</xsl:when>
					<xsl:when test="substring($country, 1, 2) = 'AR'">
						<xsl:if test="E-C082/C-3039">
							<Udf>
								<UdfCode CreateIfNotExists="Y">
									<xsl:text>CUIT</xsl:text>
								</UdfCode>
								<UdfValue>
									<xsl:value-of select="E-C082/C-3039"/>
								</UdfValue>
							</Udf>
						</xsl:if>
					</xsl:when>
					<xsl:when test="substring($country, 1, 2) = 'MX'">
						<xsl:if test="E-C082/C-3039">
							<Udf>
								<UdfCode CreateIfNotExists="Y">
									<xsl:text>RFC</xsl:text>
								</UdfCode>
								<UdfValue>
									<xsl:value-of select="E-C082/C-3039"/>
								</UdfValue>
							</Udf>
						</xsl:if>
					</xsl:when>
					<xsl:when test="substring($country, 1, 2) = 'DO'">
						<xsl:if test="E-C082/C-3039">
							<Udf>
								<UdfCode CreateIfNotExists="Y">
									<xsl:text>RNC</xsl:text>
								</UdfCode>
								<UdfValue>
									<xsl:value-of select="E-C082/C-3039"/>
								</UdfValue>
							</Udf>
						</xsl:if>
					</xsl:when>
					<xsl:when test="substring($country, 1, 2) = 'EC'">
						<xsl:if test="E-C082/C-3039">
							<Udf>
								<UdfCode CreateIfNotExists="Y">
									<xsl:text>RUC</xsl:text>
								</UdfCode>
								<UdfValue>
									<xsl:value-of select="E-C082/C-3039"/>
								</UdfValue>
							</Udf>
						</xsl:if>
					</xsl:when>
					<xsl:when test="substring($country, 1, 2) = 'VE'">
						<xsl:if test="E-C082/C-3039">
							<Udf>
								<UdfCode CreateIfNotExists="Y">
									<xsl:text>RIF</xsl:text>
								</UdfCode>
								<UdfValue>
									<xsl:value-of select="E-C082/C-3039"/>
								</UdfValue>
							</Udf>
						</xsl:if>
					</xsl:when>
					<xsl:when test="substring($country, 1, 2) = 'TR'">
						<xsl:if test="$TaxID != ''">
							<Udf>
								<UdfCode CreateIfNotExists="Y">
									<xsl:text>TAX ID</xsl:text>
								</UdfCode>
								<UdfValue>
									<xsl:value-of select="$TaxID"/>
								</UdfValue>
							</Udf>
						</xsl:if>
					</xsl:when>
					<xsl:when test="substring($country, 1, 2) = 'UY'">
						<xsl:if test="E-C082/C-3039">
							<Udf>
								<UdfCode CreateIfNotExists="Y">
									<xsl:text>RUT</xsl:text>
								</UdfCode>
								<UdfValue>
									<xsl:value-of select="E-C082/C-3039"/>
								</UdfValue>
							</Udf>
						</xsl:if>
					</xsl:when>
					<xsl:when test="substring($country, 1, 2) = 'PE'">
						<xsl:if test="E-C082/C-3039">
							<Udf>
								<UdfCode CreateIfNotExists="Y">
									<xsl:text>RUC</xsl:text>
								</UdfCode>
								<UdfValue>
									<xsl:value-of select="E-C082/C-3039"/>
								</UdfValue>
							</Udf>
						</xsl:if>
					</xsl:when>
					<xsl:when test="substring($country, 1, 2) = 'BO'">
						<xsl:if test="E-C082/C-3039">
							<Udf>
								<UdfCode CreateIfNotExists="Y">
									<xsl:text>CNPJ</xsl:text>
								</UdfCode>
								<UdfValue>
									<xsl:value-of select="E-C082/C-3039"/>
								</UdfValue>
							</Udf>
						</xsl:if>
					</xsl:when>
					<xsl:when test="substring($country, 1, 2) = 'GT'">
						<xsl:if test="E-C082/C-3039">
							<Udf>
								<UdfCode CreateIfNotExists="Y">
									<xsl:text>NIT</xsl:text>
								</UdfCode>
								<UdfValue>
									<xsl:value-of select="E-C082/C-3039"/>
								</UdfValue>
							</Udf>
						</xsl:if>
					</xsl:when>
					<xsl:when test="substring($country, 1, 2) = 'PY'">
						<xsl:if test="E-C082/C-3039">
							<Udf>
								<UdfCode CreateIfNotExists="Y">
									<xsl:text>RUC</xsl:text>
								</UdfCode>
								<UdfValue>
									<xsl:value-of select="E-C082/C-3039"/>
								</UdfValue>
							</Udf>
						</xsl:if>
					</xsl:when>
					<xsl:when test="substring($country, 1, 2) = 'CL'">
						<xsl:if test="E-C082/C-3039">
							<Udf>
								<UdfCode CreateIfNotExists="Y">
									<xsl:text>RUT</xsl:text>
								</UdfCode>
								<UdfValue>
									<xsl:value-of select="E-C082/C-3039"/>
								</UdfValue>
							</Udf>
						</xsl:if>
					</xsl:when>
					<xsl:when test="substring($country, 1, 2) = 'ID'">
						<xsl:if test="E-C082/C-3039">
							<Udf>
								<UdfCode CreateIfNotExists="Y">
									<xsl:text>TAX ID</xsl:text>
								</UdfCode>
								<UdfValue>
									<xsl:value-of select="E-C082/C-3039"/>
								</UdfValue>
							</Udf>
						</xsl:if>
					</xsl:when>
					<xsl:when test="substring($country, 1, 2) = 'CN'">
						<xsl:if test="E-C082/C-3039">
							<Udf>
								<UdfCode CreateIfNotExists="Y">
									<xsl:text>USCI</xsl:text>
								</UdfCode>
								<UdfValue>
									<xsl:value-of select="E-C082/C-3039"/>
								</UdfValue>
							</Udf>
						</xsl:if>
					</xsl:when>
					<xsl:when test="substring($country, 1, 2) = 'PK'">
						<xsl:if test="E-C082/C-3039">
							<Udf>
								<UdfCode CreateIfNotExists="Y">
									<xsl:text>NTN</xsl:text>
								</UdfCode>
								<UdfValue>
									<xsl:value-of select="E-C082/C-3039"/>
								</UdfValue>
							</Udf>
						</xsl:if>
					</xsl:when>
					<xsl:when test="substring($country, 1, 2) = 'VN'">
						<xsl:if test="E-C082/C-3039">
							<Udf>
								<UdfCode CreateIfNotExists="Y">
									<xsl:text>TAX ID</xsl:text>
								</UdfCode>
								<UdfValue>
									<xsl:value-of select="E-C082/C-3039"/>
								</UdfValue>
							</Udf>
						</xsl:if>
					</xsl:when>
					<xsl:when test="substring($country, 1, 2) = 'DZ'">
						<xsl:if test="E-C082/C-3039">
							<Udf>
								<UdfCode CreateIfNotExists="Y">
									<xsl:text>NIF</xsl:text>
								</UdfCode>
								<UdfValue>
									<xsl:value-of select="E-C082/C-3039"/>
								</UdfValue>
							</Udf>
						</xsl:if>
					</xsl:when>
				</xsl:choose>
			</PartyUdf>
		</Party>
	</xsl:template>
</xsl:stylesheet>