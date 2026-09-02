<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="2.0" xmlns:functx="http://functx.com" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:xs="http://www.w3.org/2001/XMLSchema" exclude-result-prefixes="functx xsl xs">
	<xsl:output method="xml" indent="yes" encoding="UTF-8" standalone="yes" omit-xml-declaration="no"/>
	<!--IFTMIN-->
	<xsl:param name="MessageFunctionCode"/>
	<xsl:param name="MessageSubType"/>
	<!--IFTMBF-->
	<xsl:param name="Closingdate"/>
	<xsl:param name="ETA"/>
	<xsl:param name="PreCarriage"/>
	<xsl:param name="Azone"/>
	<xsl:param name="AzoneFull"/>
	<xsl:param name="ITR"/>
	<xsl:param name="ITRFull"/>
	<xsl:param name="Forwarder"/>
	<!--OTHER-->
	<xsl:param name="defaultCompany"/>
	<xsl:param name="defaultGroup"/>
	<xsl:param name="defaultDepartment"/>
	<xsl:param name="defaultScenario"/>
	<xsl:param name="KPI-ABCNT"/>
	<xsl:param name="IFTMBF-XML"/>
	<!--TREESTRUCT-->
	<xsl:param name="Company"/>
	<xsl:param name="Group"/>
	<xsl:param name="Department"/>
	<xsl:param name="TRS-1_Company"/>
	<!--MAIN/SUB-->
	<xsl:param name="allRFF-LI"/>
	<xsl:param name="allEQD"/>

	<xsl:param name="EdifactSenderId"/>
	<xsl:param name="EdifactReceiverId"/>

	<xsl:variable name="countryCodesAndNames">
		<xsl:copy-of select="document('../XML/CountryCodesAndNames.xml')"/>
	</xsl:variable>
	
	<xsl:function name="functx:substringOnWholeWords">
		<xsl:param name="length" as="xs:integer"/>
		<xsl:param name="input"/>
		<xsl:param name="splitCharacter"/>
		
		<xsl:choose>
			<xsl:when test="string-length($input) le $length">
				<xsl:value-of select="$input"/>
			</xsl:when>
			<xsl:otherwise>
				<xsl:choose>
					<xsl:when test="substring($input, $length, 1) = $splitCharacter">
						<xsl:value-of select="substring($input, 1, $length - 1)"/>
					</xsl:when>
					<xsl:otherwise>
						<xsl:variable name="substringValue" select="substring($input, 1, $length)"/>
						<xsl:variable name="lastWord" select="tokenize($substringValue, $splitCharacter)[last()]"/>
						<xsl:value-of select="substring($substringValue, 1, string-length($substringValue) - string-length(concat($splitCharacter, $lastWord)))"/>
					</xsl:otherwise>
				</xsl:choose>		
			</xsl:otherwise>
		</xsl:choose>
	</xsl:function>
	<xsl:function name="functx:lineFeedOnWholeWords">
		<xsl:param name="length" as="xs:integer"/>
		<xsl:param name="input"/>
		<xsl:param name="splitCharacter"/>
		
		<xsl:choose>
			<xsl:when test="string-length($input) le $length">
				<xsl:value-of select="$input"/>
			</xsl:when>
			<xsl:otherwise>
				<xsl:choose>
					<xsl:when test="substring($input, $length + 1, 1) = $splitCharacter">
						<xsl:variable name="phrase" select="substring($input, 1, $length)"/>
						<xsl:value-of select="$phrase"/>
						<xsl:text>&#xa;</xsl:text>						
						<xsl:variable name="leftOver" select="substring($input, string-length($phrase) + 1)"/>						
						<xsl:value-of select="functx:lineFeedOnWholeWords($length, $leftOver, $splitCharacter)"/>
					</xsl:when>
					<xsl:otherwise>
						<xsl:variable name="substringValue" select="substring($input, 1, $length)"/>						
						<xsl:variable name="words" select="tokenize($substringValue, $splitCharacter)"/>
						
						<xsl:variable name="phrase">
							<xsl:choose>
								<xsl:when test="count($words) gt 1">									
									<xsl:value-of select="substring($substringValue, 1, string-length($substringValue) + 1 - string-length(concat($splitCharacter, $words[last()])))"/>																	
								</xsl:when>
								<xsl:otherwise>
									<xsl:value-of select="substring($input, 1, $length)"/>																
								</xsl:otherwise>
							</xsl:choose>
						</xsl:variable>	
						<xsl:value-of select="$phrase"/>
						<xsl:text>&#xa;</xsl:text>								
						<xsl:variable name="leftOver" select="substring($input, string-length($phrase) + 1)"/>						
						<xsl:value-of select="functx:lineFeedOnWholeWords($length, $leftOver, $splitCharacter)"/>
					</xsl:otherwise>
				</xsl:choose>		
			</xsl:otherwise>
		</xsl:choose>
	</xsl:function>
	
	<xsl:template match="/">
		<xsl:variable name="SERVICE_CODE">
			<xsl:choose>
				<xsl:when test="$MessageSubType = 'ERSTINFO' and $MessageFunctionCode = '9'">
					<xsl:text>ERST_CR</xsl:text>	
				</xsl:when>
				<xsl:when test="$MessageSubType = 'ERSTINFO' and $MessageFunctionCode = '4'">
					<xsl:text>ERST_UP</xsl:text>	
				</xsl:when>
				<xsl:when test="$MessageSubType = 'ERSTINFO' and $MessageFunctionCode = '1'">
					<xsl:text>ERST_CA</xsl:text>	
				</xsl:when>
				<xsl:when test="$MessageSubType = 'ABSCHLUSSINFO' and $MessageFunctionCode = '9'">
					<xsl:text>ABSC_CR</xsl:text>	
				</xsl:when>
				<xsl:when test="$MessageSubType = 'ABSCHLUSSINFO' and $MessageFunctionCode = '4'">
					<xsl:text>ABSC_UP</xsl:text>	
				</xsl:when>
				<xsl:when test="$MessageSubType = 'ABSCHLUSSINFO' and $MessageFunctionCode = '1'">
					<xsl:text>ABSC_CA</xsl:text>	
				</xsl:when>
				<xsl:otherwise>
					<xsl:text>UNKNOWN</xsl:text>
				</xsl:otherwise>
			</xsl:choose>
		</xsl:variable>
	
		<TRS_DATA>
			<ORDERS>
				<xsl:for-each select="//MainFile">
					<xsl:variable name="filePosition" select="position()"/>
					<xsl:variable name="FCLorLCL">
						<xsl:choose>
							<xsl:when test="contains(upper-case(FileScenario), 'FCL')">
								<xsl:text>FCL</xsl:text>
							</xsl:when>
							<xsl:when test="contains(upper-case(FileScenario), 'LCL')">
								<xsl:text>LCL</xsl:text>
							</xsl:when>
							<xsl:when test="contains(upper-case(FileScenario), 'RB')">
								<xsl:choose>
									<xsl:when test="count(FileContainers/Container) gt 0">
										<xsl:text>FCL</xsl:text>
									</xsl:when>
									<xsl:otherwise>
										<xsl:text>LCL</xsl:text>
									</xsl:otherwise>
								</xsl:choose>
							</xsl:when>
						</xsl:choose>
					</xsl:variable>
					<xsl:variable name="MBLorRBL">
						<xsl:choose>
							<xsl:when test="contains(upper-case(FileScenario), 'HBL')">
								<xsl:text>MBL</xsl:text>
							</xsl:when>
							<xsl:when test="contains(upper-case(FileScenario), 'RBL') and count(FileContainers/Container) = 1">
								<xsl:text>RBLasMBL</xsl:text>
							</xsl:when>
							<xsl:when test="contains(upper-case(FileScenario), 'RBL')">
								<xsl:text>RBL</xsl:text>
							</xsl:when>
							<xsl:otherwise>
								<xsl:text/>
							</xsl:otherwise>
						</xsl:choose>
					</xsl:variable>
				
					<xsl:call-template name="ORDER">
						<xsl:with-param name="BL" select="''"/>
						<xsl:with-param name="SERVICE_CODE" select="$SERVICE_CODE"/>
						<xsl:with-param name="FCLorLCL" select="$FCLorLCL"/>
						<xsl:with-param name="MBLorRBL" select="$MBLorRBL"/>
						<xsl:with-param name="filePosition" select="$filePosition"/>
					</xsl:call-template> 
					<xsl:if test="$SERVICE_CODE = 'ERST_CR'">
						<xsl:call-template name="ORDER">
							<xsl:with-param name="BL" select="concat('BL-', $filePosition)"/>
							<xsl:with-param name="SERVICE_CODE" select="$SERVICE_CODE"/>
							<xsl:with-param name="FCLorLCL" select="$FCLorLCL"/>
							<xsl:with-param name="MBLorRBL" select="$MBLorRBL"/>
							<xsl:with-param name="filePosition" select="$filePosition"/>
						</xsl:call-template>
					</xsl:if>
				</xsl:for-each>
			</ORDERS>
		</TRS_DATA>
	</xsl:template>
	<xsl:template name="ORDER">
		<xsl:param name="BL"/>
		<xsl:param name="SERVICE_CODE"/>
		<xsl:param name="FCLorLCL"/>
		<xsl:param name="MBLorRBL"/>
		<xsl:param name="filePosition"/>

		<xsl:variable name="FileTermsOfDelivery">
			<xsl:value-of select="upper-case(string-join(distinct-values(FileTermsOfDelivery), ';'))"/>
		</xsl:variable>	
		
		<xsl:variable name="POL" select="FilePortOfLoading"/>
		<xsl:variable name="POD" select="FilePortOfDischarge"/>
		<xsl:variable name="partyID_CZ" select="FileParties/Party[@Type = 'CZ']/PartyId/text()"/>
		
		<FMSWFM_ORDER DATA_LEVEL="MS">
			<xsl:attribute name="KEY" select="concat($BL, 'FMS-', $filePosition)"/>
			<xsl:choose>
				<xsl:when test="$SERVICE_CODE = 'ERST_CR'">
					<xsl:attribute name="ACTION">CREATE_UPDATE</xsl:attribute>
				</xsl:when>
				<xsl:otherwise>
					<xsl:attribute name="ACTION">UPDATE</xsl:attribute>
				</xsl:otherwise>
			</xsl:choose>
			<xsl:choose>
				<xsl:when test="string-length(normalize-space($BL)) gt 0">
					<xsl:attribute name="PARENT_KEY" select="concat('FMS-', $filePosition)"/>
				</xsl:when>
				<xsl:when test="FileSubFile">
					<xsl:attribute name="PARENT_KEY">FMS-1</xsl:attribute>
				</xsl:when>
			</xsl:choose>
			<xsl:choose>
				<xsl:when test="contains($SERVICE_CODE, 'CA')">
					<xsl:attribute name="SEARCH_FIELDS">CUSTOMER_REFERENCE,COMPANY_CODE,GROUP_CODE,PI_CATEGORY</xsl:attribute>
				</xsl:when>
				<xsl:otherwise>
					<xsl:attribute name="SEARCH_FIELDS">PI_STATUS,CUSTOMER_REFERENCE,COMPANY_CODE,GROUP_CODE,PI_CATEGORY,PI_SUBTYPE</xsl:attribute>
				</xsl:otherwise>
			</xsl:choose>
			<xsl:if test="string-length(normalize-space($BL)) le 0">
				<xsl:attribute name="SERVICE_CODE">
					<xsl:value-of select="$SERVICE_CODE"/>
				</xsl:attribute>
			</xsl:if>
			
			<xsl:text>&#xa;</xsl:text>
			<xsl:comment>
				<xsl:value-of select="concat('BL: ', $BL)"/>
				<xsl:text>&#xa;</xsl:text>
				<xsl:value-of select="concat('SERVICE_CODE: ', $SERVICE_CODE)"/>
				<xsl:text>&#xa;</xsl:text>
				<xsl:value-of select="concat('FCLorLCL: ', $FCLorLCL)"/>
				<xsl:text>&#xa;</xsl:text>
				<xsl:value-of select="concat('MBLorRBL: ', $MBLorRBL)"/>
				<xsl:text>&#xa;</xsl:text>
			</xsl:comment>
			<xsl:text>&#xa;</xsl:text>
			
			<xsl:if test="$FCLorLCL = 'LCL'">
				<xsl:variable name="RFF-LI">
					<xsl:choose>
						<xsl:when test="$MBLorRBL = 'MBL' or $MBLorRBL = 'RBLasMBL'">
							<xsl:for-each select="tokenize($allRFF-LI, '-')">
								<xsl:sort select="."/>
								<RFF-LI>
									<xsl:value-of select="."/>
								</RFF-LI>
							</xsl:for-each>
						</xsl:when>
						<xsl:otherwise>
							<xsl:for-each select="FileGoodLines/GoodLine">
								<xsl:sort select="GoodCustomerReference"/>
								<RFF-LI>
									<xsl:value-of select="normalize-space(tokenize(GoodCustomerReference, '-')[1])"/>
								</RFF-LI>
							</xsl:for-each>
						</xsl:otherwise>
					</xsl:choose>
				</xsl:variable>
				<xsl:variable name="technicalRef" select="substring(string-join(distinct-values($RFF-LI/RFF-LI), '-'), 1, 98)"/>
				<xsl:if test="string-length(normalize-space($technicalRef)) gt 0">
					<TECHNICAL_REFERENCE>
						<xsl:value-of select="$technicalRef"/>
					</TECHNICAL_REFERENCE>
				</xsl:if>
			</xsl:if>
			
			<CUSTOMER_REFERENCE>
				<xsl:value-of select="FileCustomerReference"/>
			</CUSTOMER_REFERENCE>
			<PI_STATUS>
				<xsl:choose>
					<xsl:when test="contains($SERVICE_CODE, 'CA')">
						<xsl:text>CA</xsl:text>
					</xsl:when>
					<xsl:otherwise>
						<xsl:text>OP</xsl:text>
					</xsl:otherwise>
				</xsl:choose>
			</PI_STATUS>
			<PI_CATEGORY>
				<xsl:choose>
					<xsl:when test="string-length(normalize-space($BL)) gt 0">
						<xsl:text>FMS-BL</xsl:text>
					</xsl:when>
					<xsl:otherwise>
						<xsl:text>FMS</xsl:text>
					</xsl:otherwise>
				</xsl:choose>
			</PI_CATEGORY>
			<CUSTOMER_THIRDPARTY_CODE>
				<xsl:value-of select="FileThirdParty/@ThirdPartyID"/>
			</CUSTOMER_THIRDPARTY_CODE>
			<xsl:variable name="company_code">
				<xsl:choose>
					<xsl:when test="string-length(normalize-space(FileCompany)) > 0">
						<xsl:value-of select="FileCompany"/>
					</xsl:when>
					<xsl:when test="string-length(normalize-space($Company)) > 0">
						<xsl:value-of select="$Company"/>
					</xsl:when>
					<xsl:when test="string-length(normalize-space($TRS-1_Company)) > 0">
						<xsl:value-of select="$TRS-1_Company"/>
					</xsl:when>
					<xsl:otherwise>
						<xsl:value-of select="$defaultCompany"/>
						<!--Prograse Basexml Conversions & Defaults-->
					</xsl:otherwise>
				</xsl:choose>
			</xsl:variable>
			<COMPANY_CODE>
				<xsl:value-of select="$company_code"/>
			</COMPANY_CODE>
			<GROUP_CODE>
				<xsl:choose>
					<xsl:when test="string-length(normalize-space(FileGroup)) > 0">
						<xsl:value-of select="FileGroup"/>
					</xsl:when>
					<xsl:when test="string-length(normalize-space($Group)) > 0">
						<xsl:value-of select="$Group"/>
					</xsl:when>
					<xsl:otherwise>
						<xsl:value-of select="$defaultGroup"/>
						<!--Prograse Basexml Conversions & Defaults-->
					</xsl:otherwise>
				</xsl:choose>
			</GROUP_CODE>
			<DEPARTMENT_CODE>
				<xsl:choose>
					<xsl:when test="string-length(normalize-space(FileDepartment)) > 0">
						<xsl:value-of select="FileDepartment"/>
					</xsl:when>
					<xsl:when test="string-length(normalize-space($Department)) > 0">
						<xsl:value-of select="$Department"/>
					</xsl:when>
					<xsl:otherwise>
						<xsl:value-of select="$defaultDepartment"/>
						<!--Prograse Basexml Conversions & Defaults-->
					</xsl:otherwise>
				</xsl:choose>
			</DEPARTMENT_CODE>
			<xsl:variable name="fmsSLACode">
				<xsl:variable name="slaCode">
					<xsl:choose>
						<xsl:when test="contains($partyID_CZ, '50594')">
							<xsl:text>BTC</xsl:text>
						</xsl:when>
						<xsl:otherwise>
							<xsl:value-of select="FileScenario"/>
						</xsl:otherwise>
					</xsl:choose>
				</xsl:variable>
				<xsl:choose>
					<xsl:when test="string-length(normalize-space($slaCode)) > 0">
						<xsl:choose>
							<xsl:when test="string-length(normalize-space($MBLorRBL)) gt 0">
								<xsl:choose>
									<xsl:when test="starts-with(upper-case(normalize-space($MBLorRBL)), 'RBL')">
										<xsl:choose>
											<xsl:when test="FileSubFile">
												<xsl:value-of select="concat(tokenize($slaCode, ' ')[1], ' ', $FCLorLCL, ' CARR BL')"/>
											</xsl:when>
											<xsl:otherwise>
												<xsl:value-of select="concat(tokenize($slaCode, ' ')[1], ' ', $FCLorLCL, ' MASTER FL')"/>
											</xsl:otherwise>
										</xsl:choose>
									</xsl:when>
									<xsl:otherwise>
										<xsl:choose>
											<xsl:when test="number($filePosition) gt 1">
												<xsl:value-of select="concat('S_', $slaCode)"/>
											</xsl:when>
											<xsl:otherwise>
												<xsl:value-of select="concat('M_', $slaCode)"/>
											</xsl:otherwise>
										</xsl:choose>
									</xsl:otherwise>
								</xsl:choose>
							</xsl:when>
							<xsl:when test="upper-case(normalize-space(FileStatus)) = 'TP'">
								<xsl:value-of select="concat(FileStatus, $slaCode)"/>
							</xsl:when>
							<xsl:otherwise>
								<xsl:value-of select="$slaCode"/>
							</xsl:otherwise>
						</xsl:choose>
					</xsl:when>
					<xsl:otherwise>
						<xsl:value-of select="$defaultScenario"/>
						<!--Prograse Basexml Conversions & Defaults-->
					</xsl:otherwise>
				</xsl:choose>
			</xsl:variable>
			<xsl:variable name="slaCode">
				<xsl:choose>
					<xsl:when test="string-length(normalize-space($BL)) gt 0">
						<xsl:text>BL</xsl:text>
					</xsl:when>
					<xsl:otherwise>
						<xsl:value-of select="$fmsSLACode"/>
					</xsl:otherwise>
				</xsl:choose>
			</xsl:variable>
			<xsl:if test="not(contains($SERVICE_CODE, 'CA'))">
				<SLA_CODE>
					<xsl:value-of select="$slaCode"/>
				</SLA_CODE>
			</xsl:if>
			<PI_SUBTYPE>
				<xsl:value-of select="$slaCode"/>
			</PI_SUBTYPE>
			<PI_TYPE>
				<xsl:value-of select="$slaCode"/>
			</PI_TYPE>
			<xsl:if test="string-length(normalize-space($BL)) le 0">
				<WFM_PI_TASKS>
					<WFM_PI_TASK ACTION="CREATE">
						<xsl:attribute name="KEY" select="concat('TASK-', $filePosition)"/>
						<SLA_SERVICE_CODE>
							<xsl:value-of select="concat($SERVICE_CODE, '-T')"/>
						</SLA_SERVICE_CODE>
						<STATUS>DEX</STATUS>
					</WFM_PI_TASK>
				</WFM_PI_TASKS>
			</xsl:if>
			<xsl:if test="not(contains($SERVICE_CODE, 'CA'))">
				<!-- not cancellation-->
				<DELIVERY_TERM>
					<xsl:value-of select="distinct-values(FileTermsOfDelivery)"/>
				</DELIVERY_TERM>
				<xsl:if test="string-length(normalize-space($Closingdate)) gt 0">
					<FILE_CLOSING_DATE>
						<xsl:value-of select="concat(substring($Closingdate, 1, 4), '-', substring($Closingdate, 5, 2), '-', substring($Closingdate, 7, 2), 'T00:00:00')"/>
					</FILE_CLOSING_DATE>
				</xsl:if>
				<xsl:if test="string-length(normalize-space($BL)) le 0">
					<GEN_UDF_INSTANCES>
						<GEN_UDF_INSTANCE SEARCH_FIELDS="UDF_CODE" ACTION="CREATE_UPDATE" KEY="{concat($BL, 'FUDF-REC-', $filePosition)}">
							<UDF_CODE>BASF_REC</UDF_CODE>
							<UDF_VALUE><xsl:value-of select="$EdifactSenderId"/></UDF_VALUE>
						</GEN_UDF_INSTANCE>
						<GEN_UDF_INSTANCE SEARCH_FIELDS="UDF_CODE" ACTION="CREATE_UPDATE">
							<xsl:attribute name="KEY" select="concat($BL, 'FUDF-MBF-', $filePosition, '-1')"/>
							<UDF_CODE>
								<xsl:text>BEFART</xsl:text>
							</UDF_CODE>
							<UDF_VALUE>
								<xsl:value-of select="normalize-space(string($PreCarriage))"/>
							</UDF_VALUE>
						</GEN_UDF_INSTANCE>
						<GEN_UDF_INSTANCE SEARCH_FIELDS="UDF_CODE" ACTION="CREATE_UPDATE">
							<xsl:attribute name="KEY" select="concat($BL, 'FUDF-MBF-', $filePosition, '-2')"/>
							<UDF_CODE>
								<xsl:text>AZONE</xsl:text>
							</UDF_CODE>
							<UDF_VALUE>
								<xsl:value-of select="normalize-space(string($Azone))"/>
							</UDF_VALUE>
						</GEN_UDF_INSTANCE>
						<GEN_UDF_INSTANCE SEARCH_FIELDS="UDF_CODE" ACTION="CREATE_UPDATE">
							<xsl:attribute name="KEY" select="concat($BL, 'FUDF-MBF-', $filePosition, '-3')"/>
							<UDF_CODE>
								<xsl:text>AZONEFULL</xsl:text>
							</UDF_CODE>
							<UDF_VALUE>
								<xsl:value-of select="normalize-space(string($AzoneFull))"/>
							</UDF_VALUE>
						</GEN_UDF_INSTANCE>
						<GEN_UDF_INSTANCE SEARCH_FIELDS="UDF_CODE" ACTION="CREATE_UPDATE">
							<xsl:attribute name="KEY" select="concat($BL, 'FUDF-MBF-', $filePosition, '-4')"/>
							<UDF_CODE>
								<xsl:text>ITR</xsl:text>
							</UDF_CODE>
							<UDF_VALUE>
								<xsl:value-of select="normalize-space(string($ITR))"/>
							</UDF_VALUE>
						</GEN_UDF_INSTANCE>
						<GEN_UDF_INSTANCE SEARCH_FIELDS="UDF_CODE" ACTION="CREATE_UPDATE">
							<xsl:attribute name="KEY" select="concat($BL, 'FUDF-MBF-', $filePosition, '-5')"/>
							<UDF_CODE>
								<xsl:text>ITRFULL</xsl:text>
							</UDF_CODE>
							<UDF_VALUE>
								<xsl:value-of select="normalize-space(string($ITRFull))"/>
							</UDF_VALUE>
						</GEN_UDF_INSTANCE>
						<xsl:if test="starts-with($SERVICE_CODE, 'ABSC')">
							<GEN_UDF_INSTANCE SEARCH_FIELDS="UDF_CODE" ACTION="CREATE_UPDATE">
								<xsl:attribute name="KEY" select="concat($BL, 'FUDF-MBF-', $filePosition, '-6')"/>
								<UDF_CODE>
									<xsl:text>KPI-ABCNT</xsl:text>
								</UDF_CODE>
								<UDF_VALUE>
									<xsl:value-of select="normalize-space(string($KPI-ABCNT))"/>
								</UDF_VALUE>
							</GEN_UDF_INSTANCE>
							<GEN_UDF_INSTANCE SEARCH_FIELDS="UDF_CODE" ACTION="CREATE_UPDATE">
								<xsl:attribute name="KEY" select="concat($BL, 'FUDF-MBF-', $filePosition, '-7')"/>
								<UDF_CODE>
									<xsl:text>KPI-ABDTE</xsl:text>
								</UDF_CODE>
								<UDF_VALUE>
									<xsl:value-of select="format-date(current-date(), '[D02]/[M02]/[Y0004]')"/>
								</UDF_VALUE>
							</GEN_UDF_INSTANCE>
						</xsl:if>					
						<GEN_UDF_INSTANCE SEARCH_FIELDS="UDF_CODE" ACTION="CREATE_UPDATE">
							<xsl:attribute name="KEY" select="concat($BL, 'FUDF-MBF-', $filePosition, '-8')"/>
							<UDF_CODE>
								<xsl:text>KPI-NTFY</xsl:text>
							</UDF_CODE>
							<UDF_VALUE>
								<xsl:choose>
									<xsl:when test="boolean(//Udf[UdfCode = 'FTX-DEL' and contains(UdfValue, 'NY: ')]) and boolean(//Party[@Type = 'N1'])">
										<xsl:text>Notify in delivery notifications.</xsl:text>
									</xsl:when>
									<xsl:when test="not(boolean(//Party[@Type = 'N1']))">
										<xsl:text>Notify not found.</xsl:text>
									</xsl:when>
								</xsl:choose>
							</UDF_VALUE>
						</GEN_UDF_INSTANCE>
						<GEN_UDF_INSTANCE SEARCH_FIELDS="UDF_CODE" ACTION="CREATE_UPDATE">
							<xsl:attribute name="KEY" select="concat($BL, 'FUDF-MBF-', $filePosition, '-9')"/>
							<UDF_CODE>
								<xsl:text>KPI-DEL</xsl:text>
							</UDF_CODE>
							<UDF_VALUE>
								<xsl:choose>
									<xsl:when test="boolean(//Udf[UdfCode = 'FTX-DEL' and contains(UdfValue, 'CO: ')]) and boolean(//Party[@Type = 'DO'])">
										<xsl:text>Consignee in delivery notifications.</xsl:text>
									</xsl:when>
									<xsl:when test="not(boolean(//Party[@Type = 'DO']))">
										<xsl:text>Consignee not found.</xsl:text>
									</xsl:when>
								</xsl:choose>
							</UDF_VALUE>
						</GEN_UDF_INSTANCE>		
						<GEN_UDF_INSTANCE SEARCH_FIELDS="UDF_CODE" ACTION="CREATE_UPDATE">
							<xsl:attribute name="KEY" select="concat($BL, 'FUDF-MBF-', $filePosition, '-10')"/>
							<UDF_CODE>
								<xsl:text>KPI-2NTF</xsl:text>
							</UDF_CODE>
							<UDF_VALUE>
								<xsl:choose>
									<xsl:when test="boolean(//Udf[UdfCode = 'FTX-DEL' and (contains(UdfValue, 'N2: ') or contains(UdfValue, 'NZ: '))]) and boolean(//Party[@Type = 'N2' or @Type = 'NZ'])">
										<xsl:text>Second notify in delivery notifications.</xsl:text>
									</xsl:when>
									<xsl:when test="not(boolean(//Party[@Type = 'N2' or @Type = 'NZ']))">
										<xsl:text>Second notify not found.</xsl:text>
									</xsl:when>
								</xsl:choose>
							</UDF_VALUE>
						</GEN_UDF_INSTANCE>		
						<GEN_UDF_INSTANCE SEARCH_FIELDS="UDF_CODE" ACTION="CREATE_UPDATE">
							<xsl:attribute name="KEY" select="concat($BL, 'FUDF-MBF-', $filePosition, '-11')"/>
							<UDF_CODE>
								<xsl:text>KPI-STICH</xsl:text>
							</UDF_CODE>
							<UDF_VALUE>
								<xsl:choose>
									<xsl:when test="count(distinct-values(//Udf[UdfCode = 'FTX-AAW']/UdfValue)) gt 1">
										<xsl:text>Different stichwort codes in 1 BL.</xsl:text>
									</xsl:when>
									<xsl:when test="count(distinct-values(//Udf[UdfCode = 'FTX-AAW']/UdfValue)) = 0">
										<xsl:text>Stichwort missing.</xsl:text>
									</xsl:when>
								</xsl:choose>
							</UDF_VALUE>
						</GEN_UDF_INSTANCE>
						<xsl:for-each-group select="FileUdf/Udf[not(starts-with(UdfCode, 'Sped-')) 
																			and UdfCode != 'BASF-REP' 	and UdfCode != 'PLCOFTRNSSHPM' 	and UdfCode != 'FTX-DCL'
																			and UdfCode != 'FTX-PRD'  	and UdfCode != 'FTX-DEL'       	and UdfCode != 'FTX-AAW' 			and UdfCode != 'FTX-AAA' 
																		    and UdfCode != 'FTX-ACB'  	and UdfCode != 'FTX-LOI'      	and UdfCode != 'FTX-AAC' 			
																		    and UdfCode != 'RFF-BN'   	and UdfCode != 'FTX-DIN'		and UdfCode != 'BELADEART-CODE' 
																		    and UdfCode != 'CONTRCARRIAGE-DESC'							and UdfCode != 'UNH'
																		    and UdfCode != 'UNH_NR'	 	and UdfCode != 'PLACE-TOD'		and UdfCode != 'NEW-VSSL' 			and UdfCode != 'NEW-LLOYD'
																		    and UdfCode != 'RFF-AMU'	and UdfCode != 'FTX-ABL'		and upper-case(UdfCode) != 'MESFU'	and UdfCode != 'UNB_DT'
																		    and UdfCode != 'VOYNBR'	 	and UdfCode != 'FTX-AAF'		and UdfCode != 'Place-TOD20']" group-by="UdfCode">
							<xsl:choose>
								<xsl:when test="contains(UdfCode, 'FTX-DOC')">
									<xsl:variable name="udf-1">
										<xsl:value-of select="functx:substringOnWholeWords(500, UdfValue, ' ')"/>
									</xsl:variable>
									<xsl:variable name="udf-2">
										<xsl:if test="string-length($udf-1) gt 0">
											<xsl:value-of select="functx:substringOnWholeWords(500, substring-after(UdfValue, $udf-1), ' ')"/>
										</xsl:if>
									</xsl:variable>	
									<xsl:variable name="udf-3">
										<xsl:if test="string-length($udf-2) gt 0">
											<xsl:value-of select="functx:substringOnWholeWords(500, substring-after(UdfValue, $udf-2), ' ')"/>
										</xsl:if>
									</xsl:variable>
									<GEN_UDF_INSTANCE SEARCH_FIELDS="UDF_CODE" ACTION="CREATE_UPDATE">
										<xsl:attribute name="KEY" select="concat($BL, 'FUDF-', $filePosition, '-', position(), '-1')"/>
										<UDF_CODE>
											<xsl:choose>
												<xsl:when test="starts-with(UdfCode, 'FTX') or starts-with(UdfCode, 'RFF')">
													<xsl:value-of select="concat('FL_', UdfCode, '1')"/>
												</xsl:when>
												<xsl:otherwise>
													<xsl:value-of select="UdfCode"/>
												</xsl:otherwise>
											</xsl:choose>
										</UDF_CODE>
										<UDF_VALUE>
											<xsl:value-of select="normalize-space(string($udf-1))"/>
										</UDF_VALUE>												
									</GEN_UDF_INSTANCE>
									<GEN_UDF_INSTANCE SEARCH_FIELDS="UDF_CODE" ACTION="CREATE_UPDATE">
										<xsl:attribute name="KEY" select="concat($BL, 'FUDF-', $filePosition, '-', position(), '-2')"/>														
										<UDF_CODE>
											<xsl:choose>
												<xsl:when test="starts-with(UdfCode, 'FTX') or starts-with(UdfCode, 'RFF')">
													<xsl:value-of select="concat('FL_', UdfCode, '2')"/>
												</xsl:when>
												<xsl:otherwise>
													<xsl:value-of select="UdfCode"/>
												</xsl:otherwise>
											</xsl:choose>
										</UDF_CODE>
										<UDF_VALUE>
											<xsl:value-of select="normalize-space(string($udf-2))"/>
										</UDF_VALUE>												
									</GEN_UDF_INSTANCE>
									<GEN_UDF_INSTANCE SEARCH_FIELDS="UDF_CODE" ACTION="CREATE_UPDATE">
										<xsl:attribute name="KEY" select="concat($BL, 'FUDF-', $filePosition, '-', position(), '-3')"/>														
										<UDF_CODE>
											<xsl:choose>
												<xsl:when test="starts-with(UdfCode, 'FTX') or starts-with(UdfCode, 'RFF')">
													<xsl:value-of select="concat('FL_', UdfCode, '3')"/>
												</xsl:when>
												<xsl:otherwise>
													<xsl:value-of select="UdfCode"/>
												</xsl:otherwise>
											</xsl:choose>
										</UDF_CODE>
										<UDF_VALUE>										
											<xsl:value-of select="normalize-space(string($udf-3))"/>
										</UDF_VALUE>												
									</GEN_UDF_INSTANCE>
								</xsl:when>
								<xsl:otherwise>
									<GEN_UDF_INSTANCE SEARCH_FIELDS="UDF_CODE" ACTION="CREATE_UPDATE">
										<xsl:attribute name="KEY" select="concat($BL, 'FUDF-', $filePosition, '-', position())"/>
										<xsl:for-each select="current-group()[last()]">
											<UDF_CODE>
												<xsl:choose>
													<xsl:when test="starts-with(UdfCode, 'FTX') or starts-with(UdfCode, 'RFF')">
														<xsl:value-of select="concat('FL_', UdfCode)"/>
													</xsl:when>
													<xsl:otherwise>
														<xsl:value-of select="UdfCode"/>
													</xsl:otherwise>
												</xsl:choose>
											</UDF_CODE>
											<UDF_VALUE>
												<xsl:value-of select="normalize-space(substring(UdfValue, 1, 500))"/>
											</UDF_VALUE>
										</xsl:for-each>
									</GEN_UDF_INSTANCE>
								</xsl:otherwise>
							</xsl:choose>
						</xsl:for-each-group>
						
						<xsl:for-each-group select="FileParties/Party[@Type = 'BL']" group-by="concat(PartyDescription, '-', @Type, '-', PartyId[1])">
							<xsl:variable name="BLPosition">
								<xsl:choose>
									<xsl:when test="upper-case(@Type) = 'BL'">
										<xsl:value-of select="replace(replace(replace(concat(@Type, PartyId[1]), '_NotCA', ''), '_EP', ''), '_CA', '')"/>
									</xsl:when>
									<xsl:otherwise>
										<xsl:value-of select="@Type"/>
									</xsl:otherwise>
								</xsl:choose>
							</xsl:variable>
							<xsl:for-each-group select="PartyUdf/Udf[contains(upper-case(UdfCode), 'DOC') and string-length(normalize-space(UdfValue)) gt 0]" group-by="UdfCode">
								<GEN_UDF_INSTANCE SEARCH_FIELDS="UDF_CODE" ACTION="CREATE_UPDATE">
									<xsl:attribute name="KEY" select="concat($BL, 'FUDF-PA-', $filePosition, '-', $BLPosition, '-', position())"/>
									<xsl:for-each select="current-group()[last()]">
										<UDF_CODE>
											<xsl:value-of select="concat($BLPosition, '_', UdfCode)"/>
										</UDF_CODE>
										<UDF_VALUE>
											<xsl:value-of select="normalize-space(substring(UdfValue, 1, 500))"/>
										</UDF_VALUE>
									</xsl:for-each>
								</GEN_UDF_INSTANCE>
							</xsl:for-each-group>
							
							<xsl:variable name="summary">
								<xsl:for-each-group select="PartyUdf/Udf[contains(upper-case(UdfCode), 'DOC') and string-length(normalize-space(UdfValue)) gt 0]" group-by="UdfCode">
									<xsl:sort select="UdfCode"/>
									<value>
										<xsl:value-of select="concat(substring(tokenize(UdfCode, '-')[last()], 1, 1), ': ', normalize-space(substring(UdfValue, 1, 500)))"/>
									</value>
								</xsl:for-each-group>
							</xsl:variable>
							<GEN_UDF_INSTANCE SEARCH_FIELDS="UDF_CODE" ACTION="CREATE_UPDATE">
								<xsl:attribute name="KEY" select="concat($BL, 'FUDF-PA-SUM-', $filePosition, '-', $BLPosition, '-', position())"/>
								<xsl:for-each select="current-group()[last()]">
									<UDF_CODE>
										<xsl:value-of select="concat($BLPosition, '_SUM')"/>
									</UDF_CODE>
									<UDF_VALUE>
										<xsl:value-of select="concat(string-join($summary/value, ' - '), ' - ', PartyLetterOfCredit1, ' - ', PartyDescription)"/>
									</UDF_VALUE>
								</xsl:for-each>
							</GEN_UDF_INSTANCE>							
						</xsl:for-each-group>
					</GEN_UDF_INSTANCES>
				</xsl:if>
				<FMSDOM_TRANSPORTS>
					<xsl:if test="$SERVICE_CODE != 'ERST_CR' and string-length(normalize-space($MBLorRBL)) le 0">
						<xsl:attribute name="ACTION">
							<xsl:text>DELETE_NOT_CU</xsl:text>
						</xsl:attribute>
					</xsl:if>
					<xsl:if test="string-length(normalize-space($BL)) le 0">
						<xsl:choose>
							<xsl:when test="FileContainers/Container">
								<xsl:if test="	(number($filePosition) le 1 and string-length(normalize-space($MBLorRBL)) gt 0) or 
												(number($filePosition) le 1 and string-length(normalize-space($MBLorRBL)) le 0)">
									<xsl:for-each-group select="FileContainers/Container" group-by="ContContainerNumber">
										<xsl:variable name="transportPosition">
											<xsl:choose>
												<xsl:when test="string-length(normalize-space(ID)) gt 0">
													<xsl:value-of select="ID"/>
												</xsl:when>
												<xsl:otherwise>
													<xsl:variable name="containerNumber" select="ContContainerNumber"/>
													<xsl:value-of select="//Container[ContContainerNumber = $containerNumber and string-length(normalize-space(ID)) gt 0][1]/ID"/>
												</xsl:otherwise>
											</xsl:choose>
										</xsl:variable>
										<xsl:if test="string-length(normalize-space($transportPosition)) gt 0">
											<FMSDOM_TRANSPORT SEARCH_FIELDS="TRANSPORT_MODE,REMARKS" ACTION="CREATE_UPDATE">
												
												<xsl:attribute name="KEY" select="concat($BL, 'FTR-PRE-', $filePosition, '-', $transportPosition)"/>										
												<TRANSPORT_MODE>PRE</TRANSPORT_MODE>						
												<TYPE>
													<xsl:value-of select="$PreCarriage"/>
												</TYPE>
												<TYPEBEHAVIOUR>
													<xsl:value-of select="$PreCarriage"/>
												</TYPEBEHAVIOUR>
												<SUPPLIER_PARTY_ID>
													<xsl:for-each-group select="../../FileParties/Party[@Type != 'AG' and (PartyId != '' or PartyDescription != '')]" group-by="concat(PartyDescription, '-', @Type, '-', PartyId[1])">
														<xsl:if test="upper-case(@Type) = 'EP'">
															<xsl:if test="string-length(normalize-space($BL)) gt 0">
																<xsl:text>1</xsl:text>
															</xsl:if>
															<xsl:value-of select="concat('9999', $filePosition, position())"/>
														</xsl:if>
													</xsl:for-each-group>
												</SUPPLIER_PARTY_ID>
												<REMARKS>
													<xsl:variable name="RFF-LI">
														<xsl:choose>
															<xsl:when test="$MBLorRBL = 'MBL' or $MBLorRBL = 'RBLasMBL'">
																<xsl:for-each select="tokenize($allRFF-LI, '-')">
																	<xsl:sort select="."/>
																	<RFF-LI>
																		<xsl:value-of select="."/>
																	</RFF-LI>
																</xsl:for-each>
															</xsl:when>
															<xsl:otherwise>
																<xsl:for-each select="//FileGoodLines/GoodLine[Containers/Container/ContainerID = $transportPosition]">
																	<xsl:sort select="GoodCustomerReference"/>
																	<RFF-LI>
																		<xsl:value-of select="normalize-space(tokenize(GoodCustomerReference, '-')[1])"/>
																	</RFF-LI>
																</xsl:for-each>
															</xsl:otherwise>
														</xsl:choose>
													</xsl:variable>
													<xsl:value-of select="string-join(distinct-values($RFF-LI/RFF-LI), '-')"/>
												</REMARKS>
												<FMSDOM_TRANSPORT_STOPS>
													<FMSDOM_TRANSPORT_STOP SEARCH_FIELDS="PLACE_QUALIFIER,HANDLING_TYPE" ACTION="CREATE_UPDATE">
														<xsl:attribute name="KEY" select="concat($BL, 'FTRS-PRE-', $filePosition, '-', $transportPosition, '-1')"/>
														<PLACE_QUALIFIER>88</PLACE_QUALIFIER>
														<HANDLING_TYPE>LOAD</HANDLING_TYPE>
														<LOCATION_OWNING_ENTITY>GEN_LOCODES</LOCATION_OWNING_ENTITY>
														<LOCATION_OWNING_CODE>
															<xsl:value-of select="$Azone"/>
														</LOCATION_OWNING_CODE>
														<LOCATION_NAME>
															<xsl:value-of select="$AzoneFull"/>
														</LOCATION_NAME>
														<ADDRESS_CITY>
															<xsl:value-of select="$Azone"/>
														</ADDRESS_CITY>
														<xsl:if test="matches($ITRFull, '^\d{2}.\d{2}.\d{4}$')">
															<START_TIME><!--10.07.2019-->
																<xsl:value-of select="concat(substring(tokenize($ITRFull, '\.')[last()], 1, 4), '-', tokenize($ITRFull, '\.')[2], '-', tokenize($ITRFull, '\.')[1], 'T00:00:00')"/>
															</START_TIME>
														</xsl:if>	
													</FMSDOM_TRANSPORT_STOP>
													<FMSDOM_TRANSPORT_STOP SEARCH_FIELDS="PLACE_QUALIFIER,HANDLING_TYPE" ACTION="CREATE_UPDATE">
														<xsl:attribute name="KEY" select="concat($BL, 'FTRS-PRE-', $filePosition, '-', $transportPosition, '-2')"/>
														<PLACE_QUALIFIER>9P</PLACE_QUALIFIER>
														<HANDLING_TYPE>UNLOAD</HANDLING_TYPE>
														<LOCATION_OWNING_ENTITY>GEN_LOCODES</LOCATION_OWNING_ENTITY>
														<LOCATION_OWNING_CODE>
															<xsl:value-of select="../../FilePortOfLoading"/>
														</LOCATION_OWNING_CODE>
														<LOCATION_NAME>
															<xsl:value-of select="../../FilePortOfLoading"/>
														</LOCATION_NAME>
													</FMSDOM_TRANSPORT_STOP>
												</FMSDOM_TRANSPORT_STOPS>
												
												<FMSDOM_TRANSPORT_GIETS>
													<xsl:for-each select="//FileGoodLines/GoodLine[Containers/Container/ContainerID = $transportPosition]">
														<FMSDOM_TRANSPORT_GIET>
															<xsl:attribute name="RELATION_IDENTIFIER">
																<xsl:value-of select="concat($BL, 'FCO-GO-IT-PRE-', ID)"/>
															</xsl:attribute>
														</FMSDOM_TRANSPORT_GIET>
													</xsl:for-each>								
												</FMSDOM_TRANSPORT_GIETS>
											</FMSDOM_TRANSPORT>
										</xsl:if>
									</xsl:for-each-group>
								</xsl:if>
							</xsl:when>
							<xsl:otherwise>
								<xsl:if test="number($filePosition) le 1">
									<FMSDOM_TRANSPORT SEARCH_FIELDS="TRANSPORT_MODE,REMARKS" ACTION="CREATE_UPDATE">
										<xsl:attribute name="KEY" select="concat($BL, 'FTR-PRE')"/>
										<xsl:variable name="technicalRef" select="tokenize(FileUdf/Udf[UdfCode = 'RFF-AIW']/UdfValue, ';')[1]"/>
										<xsl:if test="string-length(normalize-space($technicalRef)) gt 0">
											<TECHNICAL_REFERENCE>
												<xsl:value-of select="$technicalRef"/>
											</TECHNICAL_REFERENCE>
										</xsl:if>
										<TRANSPORT_MODE>PRE</TRANSPORT_MODE>						
										<TYPE>
											<xsl:value-of select="$PreCarriage"/>
										</TYPE>
										<TYPEBEHAVIOUR>
											<xsl:value-of select="$PreCarriage"/>
										</TYPEBEHAVIOUR>
										<REMARKS>NO CONTAINERS</REMARKS>
										<SUPPLIER_PARTY_ID>
											<xsl:for-each-group select="FileParties/Party[@Type != 'AG' and (PartyId != '' or PartyDescription != '')]" group-by="concat(PartyDescription, '-', @Type, '-', PartyId[1])">
												<xsl:if test="upper-case(@Type) = 'EP'">
													<xsl:if test="string-length(normalize-space($BL)) gt 0">
														<xsl:text>1</xsl:text>
													</xsl:if>
													<xsl:value-of select="concat('9999', $filePosition, position())"/>
												</xsl:if>
											</xsl:for-each-group>
										</SUPPLIER_PARTY_ID>
										<FMSDOM_TRANSPORT_STOPS>
											<FMSDOM_TRANSPORT_STOP SEARCH_FIELDS="PLACE_QUALIFIER,HANDLING_TYPE" ACTION="CREATE_UPDATE">
												<xsl:attribute name="KEY" select="concat($BL, 'FTRS-PRE-1')"/>
												<PLACE_QUALIFIER>88</PLACE_QUALIFIER>
												<HANDLING_TYPE>LOAD</HANDLING_TYPE>
												<LOCATION_OWNING_ENTITY>GEN_LOCODES</LOCATION_OWNING_ENTITY>
												<LOCATION_OWNING_CODE>
													<xsl:value-of select="$Azone"/>
												</LOCATION_OWNING_CODE>
												<LOCATION_NAME>
													<xsl:value-of select="$AzoneFull"/>
												</LOCATION_NAME>
												<ADDRESS_CITY>
													<xsl:value-of select="$Azone"/>
												</ADDRESS_CITY>
												<xsl:if test="matches($ITRFull, '^\d{2}.\d{2}.\d{4}$')">
													<START_TIME><!--10.07.2019-->
														<xsl:value-of select="concat(substring(tokenize($ITRFull, '\.')[last()], 1, 4), '-', tokenize($ITRFull, '\.')[2], '-', tokenize($ITRFull, '\.')[1], 'T00:00:00')"/>
													</START_TIME>
												</xsl:if>	
											</FMSDOM_TRANSPORT_STOP>
											<FMSDOM_TRANSPORT_STOP SEARCH_FIELDS="PLACE_QUALIFIER,HANDLING_TYPE" ACTION="CREATE_UPDATE">
												<xsl:attribute name="KEY" select="concat($BL, 'FTRS-PRE-2')"/>
												<PLACE_QUALIFIER>9P</PLACE_QUALIFIER>
												<HANDLING_TYPE>UNLOAD</HANDLING_TYPE>
												<LOCATION_OWNING_ENTITY>GEN_LOCODES</LOCATION_OWNING_ENTITY>
												<LOCATION_OWNING_CODE>
													<xsl:value-of select="FilePortOfLoading"/>
												</LOCATION_OWNING_CODE>
												<LOCATION_NAME>
													<xsl:value-of select="FilePortOfLoading"/>
												</LOCATION_NAME>
											</FMSDOM_TRANSPORT_STOP>
										</FMSDOM_TRANSPORT_STOPS>
										
										<FMSDOM_TRANSPORT_GIETS>
											<xsl:for-each select="//GoodLine">
												<FMSDOM_TRANSPORT_GIET>
													<xsl:attribute name="RELATION_IDENTIFIER">
														<xsl:value-of select="concat($BL, 'FCO-GO-IT-PRE-', ID)"/>
													</xsl:attribute>
												</FMSDOM_TRANSPORT_GIET>
											</xsl:for-each>								
										</FMSDOM_TRANSPORT_GIETS>
									</FMSDOM_TRANSPORT>
								</xsl:if>
							</xsl:otherwise>
						</xsl:choose>						
					</xsl:if>
					<xsl:if test="number($filePosition) le 1 or 
									(number($filePosition) gt 1 and string-length(normalize-space($MBLorRBL)) gt 0 and string-length(normalize-space($BL)) gt 0)">
						<FMSDOM_TRANSPORT SEARCH_FIELDS="TRANSPORT_MODE" ACTION="CREATE_UPDATE">
							<xsl:attribute name="KEY" select="concat($BL, 'FTR-MAIN-', $filePosition)"/>
							<xsl:variable name="technicalRef" select="FileUdf/Udf[UdfCode = 'RFF-AHI']/UdfValue"/>
							<xsl:if test="string-length(normalize-space($technicalRef)) gt 0">
								<TECHNICAL_REFERENCE>
									<xsl:value-of select="$technicalRef"/>
								</TECHNICAL_REFERENCE>
							</xsl:if>
							<TRANSPORT_MODE>MAIN</TRANSPORT_MODE>
							<TYPE>11</TYPE>
							<!--VESSEL-->
							<TYPEBEHAVIOUR>11</TYPEBEHAVIOUR>
							<SUPPLIER_PARTY_ID>
								<xsl:for-each-group select="FileParties/Party[@Type != 'AG' and (PartyId != '' or PartyDescription != '')]" group-by="concat(PartyDescription, '-', @Type, '-', PartyId[1])">
									<xsl:if test="upper-case(@Type) = 'CA' and 
												  not(upper-case(@Type) = 'CA' and contains('ERST_UP;ABSC_CR;ABSC_UP', $SERVICE_CODE) and contains('FPLES;FRACHTITA', $company_code))">
										<xsl:if test="string-length(normalize-space($BL)) gt 0">
											<xsl:text>1</xsl:text>
										</xsl:if>
										<xsl:value-of select="concat('9999', $filePosition, position())"/>
									</xsl:if>
								</xsl:for-each-group>
							</SUPPLIER_PARTY_ID>
							
							<CARRIER_BOOKING_NBR>
								<xsl:value-of select="FileAgentReference"/>
							</CARRIER_BOOKING_NBR>
							
							<xsl:if test="$SERVICE_CODE = 'ERST_CR'">							
								<TRANSPORT_IDENTIFIER>
									<xsl:value-of select="FileMainCarriage"/>
								</TRANSPORT_IDENTIFIER>
							</xsl:if>													
							<xsl:if test="string-length(normalize-space($Closingdate)) gt 0">
								<CLOSING_TIME>
									<xsl:value-of select="concat(substring($Closingdate, 1, 4), '-', substring($Closingdate, 5, 2), '-', substring($Closingdate, 7, 2), 'T00:00:00')"/>
								</CLOSING_TIME>
							</xsl:if>							

							<FMS_TRANSPORT_CLAUSES>
								<FMS_TRANSPORT_CLAUSE SEARCH_FIELDS="TYPE" ACTION="CREATE">
									<xsl:attribute name="KEY" select="concat($BL, 'FTRC-MAIN-0-', $filePosition)"/>
									<TYPE>C</TYPE>
									<CONTENT>
										<xsl:choose>
											<xsl:when test="contains($FileTermsOfDelivery, 'CIP') or contains($FileTermsOfDelivery, 'CPT') or 
												 contains($FileTermsOfDelivery, 'DDP') or contains($FileTermsOfDelivery, 'DAP') or 
												 contains($FileTermsOfDelivery, 'DPU')">
												<xsl:text>FREIGHT AND ON CARRIAGE PREPAID&#10;SHIPPED ON BOARD</xsl:text>
											</xsl:when>
											<xsl:otherwise>
												<xsl:text>FREIGHT PREPAID&#10;SHIPPED ON BOARD</xsl:text>
											</xsl:otherwise>
										</xsl:choose>
										<xsl:if test="not(FileSubFile)">
											<xsl:text>&#10;SHIPPER'S LOAD STOW AND COUNT</xsl:text>
										</xsl:if>
									</CONTENT>
								</FMS_TRANSPORT_CLAUSE>

								<xsl:if test="starts-with(FilePortOfDischarge, 'US')">
									<FMS_TRANSPORT_CLAUSE SEARCH_FIELDS="TYPE" ACTION="CREATE">
										<xsl:attribute name="KEY" select="concat($BL, 'FTRC-MAIN-1-', $filePosition)"/>									
										<TYPE>C</TYPE>									
										<CONTENT>
											<xsl:text>FOR CHEMICAL EMERGENCY (SPILL-LEAK-FIRE EXPOSURE OR ACCIDENT) CALL
EMERGENCY RESPONSE CENTER BASF: +1 800 832 4357
USA EMERGENCY CONTACT: CHEMTREC +1 800 424 9300 or +1 703 527 3887</xsl:text>
										</CONTENT>
									</FMS_TRANSPORT_CLAUSE>
								</xsl:if>
									
								<xsl:variable name="udfBLParties" select="string-join(FileParties/Party[@Type = 'BL']/PartyUdf/Udf[UdfCode != 'PANAME']/UdfValue, '')"/>
								<xsl:if test="contains($udfBLParties, 'AA')">
									<xsl:variable name="panameBLParties" select="string-join(FileParties/Party[@Type = 'BL']/PartyUdf/Udf[UdfCode = 'PANAME']/UdfValue, '')"/>
									<xsl:choose>
										<xsl:when test="contains($panameBLParties, 'BASF S.A.') or contains($panameBLParties, 'BASF SA') or contains($panameBLParties, 'BASF S.A') or contains($panameBLParties, 'BASF S/A')">
											<FMS_TRANSPORT_CLAUSE SEARCH_FIELDS="TYPE" ACTION="CREATE">
												<xsl:attribute name="KEY" select="concat($BL, 'FTRC-MAIN-2-', $filePosition)"/>									
												<TYPE>C</TYPE>									
												<CONTENT>
													<xsl:text>CONTAINS WOOD TREATED ACCORDING TO ISPM15 STANDARDS
**PRINT INSTRUCTIONS**
************************************************************
3/3 ORIGINAL BLADINGS + 6 COPIES TO BE PRINTED AT DESTINATION
************************************************************</xsl:text>
												</CONTENT>
											</FMS_TRANSPORT_CLAUSE>
										</xsl:when>
										<xsl:when test="contains($panameBLParties, 'DUBAI') or contains($panameBLParties, 'FZE')">
											<FMS_TRANSPORT_CLAUSE SEARCH_FIELDS="TYPE" ACTION="CREATE">
												<xsl:attribute name="KEY" select="concat($BL, 'FTRC-MAIN-2-', $filePosition)"/>									
												<TYPE>C</TYPE>									
												<CONTENT>
												<xsl:text>**PRINT INSTRUCTIONS**
*******************************************************
3/3 ORIGINAL BL + 6 COPIES TO BE PRINTED AT BASF FZE, DUBAI
*******************************************************</xsl:text>
												</CONTENT>
											</FMS_TRANSPORT_CLAUSE>
										</xsl:when>
										<xsl:when test="contains($panameBLParties, 'SINGAPORE')">
											<FMS_TRANSPORT_CLAUSE SEARCH_FIELDS="TYPE" ACTION="CREATE">
												<xsl:attribute name="KEY" select="concat($BL, 'FTRC-MAIN-2-', $filePosition)"/>									
												<TYPE>C</TYPE>									
												<CONTENT>
													<xsl:text>**PRINT INSTRUCTIONS**
************************************************************
3/3 ORIGINAL B/L + 6 COPIES TO BE PRINTED AT CARRIER'S AGENTS AT
SINGAPORE &amp; RELEASE TO HSBC
************************************************************</xsl:text>
												</CONTENT>
											</FMS_TRANSPORT_CLAUSE>
										</xsl:when>
										<xsl:when test="contains($panameBLParties, 'ISTANBUL')">
											<FMS_TRANSPORT_CLAUSE SEARCH_FIELDS="TYPE" ACTION="CREATE">
												<xsl:attribute name="KEY" select="concat($BL, 'FTRC-MAIN-2-', $filePosition)"/>									
												<TYPE>C</TYPE>									
												<CONTENT>											
													<xsl:text>**PRINT INSTRUCTIONS**
***********************************************************
3/3 ORIGINAL B/L + 6 COPIES TO BE PRINTED AT CARRIER'S AGENTS IN
ISTANBUL-TURKEY
***********************************************************</xsl:text>
												</CONTENT>
											</FMS_TRANSPORT_CLAUSE>
										</xsl:when>
										<xsl:when test="contains($panameBLParties, 'Malaysia')">
											<FMS_TRANSPORT_CLAUSE SEARCH_FIELDS="TYPE" ACTION="CREATE">
												<xsl:attribute name="KEY" select="concat($BL, 'FTRC-MAIN-2-', $filePosition)"/>									
												<TYPE>C</TYPE>									
												<CONTENT>
													<xsl:text>**PRINT INSTRUCTIONS**
************************************************************
3/3 OBL + 6 COPIES TO BE ISSUED AT CARRIER'S AGENTS AT MALAYSIA
AND SENT TO BASF ASIA PACIFIC SERVICE CENTRE
SDN BHD, LEVEL 25. MENARA TM, JALAN PANTAI BAHARU,
59200 KUALA LUMPUR MALAYSIA
************************************************************</xsl:text>
												</CONTENT>
											</FMS_TRANSPORT_CLAUSE>
										</xsl:when>
										<xsl:otherwise>
											<FMS_TRANSPORT_CLAUSE SEARCH_FIELDS="TYPE" ACTION="CREATE">
												<xsl:attribute name="KEY" select="concat($BL, 'FTRC-MAIN-2-', $filePosition)"/>									
												<TYPE>C</TYPE>									
												<CONTENT>
													<xsl:text>**PRINT INSTRUCTIONS**
***********************************************************
3/3 ORIGINAL BLADINGS + 6 COPIES TO BE PRINTED AT DESTINATION
***********************************************************</xsl:text>
												</CONTENT>
											</FMS_TRANSPORT_CLAUSE>
										</xsl:otherwise>
									</xsl:choose>
								</xsl:if>
								
								<xsl:if test="starts-with(upper-case(normalize-space(FilePortOfDischarge)), 'EG')">
									<xsl:variable name="gtin" select="string-join(distinct-values(FileGoodLines/GoodLine/GoodUdf/Udf[UdfCode = 'GTIN']/UdfValue), ', ')"/>
									<xsl:variable name="acid" select="string-join(distinct-values(FileGoodLines/GoodLine/GoodUdf/Udf[UdfCode = 'ACID']/UdfValue), ', ')"/>
									<xsl:if test="string-length(normalize-space($gtin)) gt 0 or string-length(normalize-space($acid)) gt 0">
										<FMS_TRANSPORT_CLAUSE SEARCH_FIELDS="TYPE" ACTION="CREATE">
											<xsl:attribute name="KEY" select="concat($BL, 'FTRC-MAIN-5-', $filePosition)"/>									
											<TYPE>C</TYPE>									
											<CONTENT>
												<xsl:if test="string-length(normalize-space($gtin)) gt 0">
													<xsl:value-of select="concat('GTIN: ', $gtin)"/>												
												</xsl:if>
												<xsl:if test="string-length(normalize-space($gtin)) gt 0 and string-length(normalize-space($acid)) gt 0">
													<xsl:text>&#10;</xsl:text>
												</xsl:if>
												<xsl:if test="string-length(normalize-space($acid)) gt 0">
													<xsl:value-of select="concat('ACID No: ', $acid)"/>
												</xsl:if>
											</CONTENT>
										</FMS_TRANSPORT_CLAUSE>
									</xsl:if>
								</xsl:if>
								
								<FMS_TRANSPORT_CLAUSE SEARCH_FIELDS="TYPE" ACTION="CREATE">
									<xsl:attribute name="KEY" select="concat($BL, 'FTRC-MAIN-3-', $filePosition)"/>									
									<TYPE>NP</TYPE>									
									<CONTENT>
										<xsl:text>Name, address and phone number of the carriers agent at port of destination.</xsl:text>
									</CONTENT>
								</FMS_TRANSPORT_CLAUSE>
								
								<xsl:for-each-group select="FileParties/Party[@Type = 'OS' or @Type = 'DO' or @Type = 'N1' or @Type = 'N2']" group-by="concat(PartyDescription, '-', @Type, '-', PartyId[1])">
									<xsl:variable name="value">
										<xsl:value-of select="functx:lineFeedOnWholeWords(35, PartyAddressName1, ' ')"/>
										<xsl:text>&#10;</xsl:text>
										<xsl:if test="string-length(normalize-space(PartyAddressName2)) gt 0">
											<xsl:value-of select="functx:lineFeedOnWholeWords(35, PartyAddressName2, ' ')"/>
											<xsl:text>&#10;</xsl:text>
										</xsl:if>
										<xsl:if test="string-length(normalize-space(PartyAddressName3)) gt 0">
											<xsl:value-of select="functx:lineFeedOnWholeWords(35, PartyAddressName3, ' ')"/>
											<xsl:text>&#10;</xsl:text>
										</xsl:if>
										<xsl:value-of select="functx:lineFeedOnWholeWords(35, PartyAddressName, ' ')"/>
										<xsl:text>&#10;</xsl:text>
										<xsl:variable name="country" select="upper-case(PartyAddressCountry)"/>
										<xsl:value-of select="functx:lineFeedOnWholeWords(35, normalize-space(concat(PartyAddressZipcode, ' ', PartyAddressCity, ' ', $countryCodesAndNames/TRIS_DATA_UPDATE/GEN_COUNTRIES/GEN_COUNTRY[CODE = $country]/NAME)), ' ')"/>						
										<xsl:if test="string-length(normalize-space(PartyContactTelephone)) gt 0">
											<xsl:text>&#10;</xsl:text>
											<xsl:value-of select="functx:lineFeedOnWholeWords(35, concat('Tel: ', PartyContactTelephone), ' ')"/>									
										</xsl:if>
										<xsl:if test="string-length(normalize-space(PartyContactFax)) gt 0 and normalize-space(upper-case(PartyContactFax)) != 'AS AGENTS ONLY'">
											<xsl:text>&#10;</xsl:text>
											<xsl:value-of select="functx:lineFeedOnWholeWords(35, concat('Fax: ', PartyContactFax), ' ')"/>
										</xsl:if>
										<xsl:if test="string-length(normalize-space(PartyContactFax)) gt 0 and normalize-space(upper-case(PartyContactFax)) = 'AS AGENTS ONLY'">
											<xsl:text>&#10;</xsl:text>
											<xsl:value-of select="functx:lineFeedOnWholeWords(35, PartyContactFax, ' ')"/>
										</xsl:if>
										<xsl:if test="string-length(normalize-space(PartyLetterOfCredit1)) gt 0">
											<xsl:text>&#10;</xsl:text>
											<xsl:value-of select="functx:lineFeedOnWholeWords(35, concat('Email: ', PartyLetterOfCredit1), ' ')"/>
										</xsl:if>
										<xsl:if test="contains(upper-case(@Type), 'OS')">
											<xsl:text>&#10;</xsl:text>
											<xsl:value-of select="../../FileCustomerReference"/>
										</xsl:if>
									</xsl:variable>
									<xsl:if test="count(tokenize($value, '&#10;')) gt 6">
										<FMS_TRANSPORT_CLAUSE SEARCH_FIELDS="TYPE" ACTION="CREATE">
											<xsl:attribute name="KEY" select="concat($BL, 'FTRC-MAIN-4-', $filePosition, '-', position())"/>											
											<TYPE>C</TYPE>									
											<CONTENT>
												<xsl:choose>
													<xsl:when test="@Type = 'OS'">
														<xsl:text>Extra Shipper information:&#10;</xsl:text>
													</xsl:when>
													<xsl:when test="@Type = 'DO'">
														<xsl:text>Extra Consignee information:&#10;</xsl:text>
													</xsl:when>
													<xsl:when test="@Type = 'N1'">
														<xsl:text>Extra Notify information:&#10;</xsl:text>
													</xsl:when>
													<xsl:when test="@Type = 'N2'">
														<xsl:text>Extra Second Notify information:&#10;</xsl:text>
													</xsl:when>												
												</xsl:choose>
												<xsl:variable name="numberOfTokens" select="count(tokenize($value, '&#10;'))"/>
												<xsl:for-each select="tokenize($value, '&#10;')">
													<xsl:choose>
														<xsl:when test="position() gt 6">															
															<xsl:value-of select="."/>
															<xsl:if test="position() lt $numberOfTokens">
																<xsl:text>&#10;</xsl:text>
															</xsl:if>
														</xsl:when>													
													</xsl:choose>
												</xsl:for-each>																							
											</CONTENT>
										</FMS_TRANSPORT_CLAUSE>
									</xsl:if>
								</xsl:for-each-group>
							</FMS_TRANSPORT_CLAUSES>						
							
							<FMSDOM_TRANSPORT_STOPS>
								<FMSDOM_TRANSPORT_STOP SEARCH_FIELDS="PLACE_QUALIFIER,HANDLING_TYPE" ACTION="CREATE_UPDATE">
									<xsl:attribute name="KEY" select="concat($BL, 'FTRS-MAIN-1-', $filePosition)"/>
									<PLACE_QUALIFIER>9</PLACE_QUALIFIER>
									<HANDLING_TYPE>LOAD</HANDLING_TYPE>
									<LOCATION_OWNING_ENTITY>GEN_LOCODES</LOCATION_OWNING_ENTITY>
									<LOCATION_OWNING_CODE>
										<xsl:value-of select="FilePortOfLoading"/>
									</LOCATION_OWNING_CODE>
									<START_TIME>
										<xsl:value-of select="concat(tokenize(FileEtd, '/')[last()], '-', tokenize(FileEtd, '/')[2], '-', tokenize(FileEtd, '/')[1], 'T00:00:00')"/>
									</START_TIME>															
								</FMSDOM_TRANSPORT_STOP>
								<FMSDOM_TRANSPORT_STOP SEARCH_FIELDS="PLACE_QUALIFIER,HANDLING_TYPE" ACTION="CREATE_UPDATE">
									<xsl:attribute name="KEY" select="concat($BL, 'FTRS-MAIN-2-', $filePosition)"/>
									<PLACE_QUALIFIER>11</PLACE_QUALIFIER>
									<HANDLING_TYPE>UNLOAD</HANDLING_TYPE>
									<LOCATION_OWNING_ENTITY>GEN_LOCODES</LOCATION_OWNING_ENTITY>
									<LOCATION_OWNING_CODE>
										<xsl:value-of select="FilePortOfDischarge"/>
									</LOCATION_OWNING_CODE>
									<xsl:if test="string-length(normalize-space($ETA)) gt 0">
										<START_TIME>
											<xsl:value-of select="concat(substring($ETA, 1, 4), '-', substring($ETA, 5, 2), '-', substring($ETA, 7, 2), 'T00:00:00')"/>
										</START_TIME>
									</xsl:if>
								</FMSDOM_TRANSPORT_STOP>
								<xsl:if test="string-length(normalize-space($BL)) gt 0 and
												(contains($FileTermsOfDelivery, 'CIP') or contains($FileTermsOfDelivery, 'CPT') or 
												 contains($FileTermsOfDelivery, 'DDP') or contains($FileTermsOfDelivery, 'DAP') or 
												 contains($FileTermsOfDelivery, 'DPU'))">
									<FMSDOM_TRANSPORT_STOP SEARCH_FIELDS="PLACE_QUALIFIER,HANDLING_TYPE" ACTION="CREATE_UPDATE">
										<xsl:attribute name="KEY" select="concat($BL, 'FTRS-MAIN-3-', $filePosition)"/>										
										<PLACE_QUALIFIER>7</PLACE_QUALIFIER>
										<HANDLING_TYPE>UNLOAD</HANDLING_TYPE>
										<LOCATION_NAME>
											<xsl:value-of select="FileUdf/Udf[UdfCode = 'Place-TOD']/UdfValue"/>
										</LOCATION_NAME>
									</FMSDOM_TRANSPORT_STOP>
								</xsl:if>
							</FMSDOM_TRANSPORT_STOPS>
							<GEN_UDF_INSTANCES>
								<GEN_UDF_INSTANCE SEARCH_FIELDS="UDF_CODE" ACTION="CREATE_UPDATE" KEY="{concat($BL, 'TUDF-REC-', $filePosition)}">
									<UDF_CODE>BASF_REC</UDF_CODE>
									<UDF_VALUE><xsl:value-of select="$EdifactSenderId"/></UDF_VALUE>
								</GEN_UDF_INSTANCE>
								<GEN_UDF_INSTANCE SEARCH_FIELDS="UDF_CODE" ACTION="CREATE_UPDATE">
									<xsl:attribute name="KEY" select="concat($BL, 'TUDF-VOYNBR-', $filePosition)"/>
									<UDF_CODE>VOYNBR</UDF_CODE>
									<UDF_VALUE>
										<xsl:value-of select="normalize-space(FileUdf/Udf[UdfCode = 'VOYNBR']/UdfValue)"/>
									</UDF_VALUE>
								</GEN_UDF_INSTANCE>
								<GEN_UDF_INSTANCE SEARCH_FIELDS="UDF_CODE" ACTION="CREATE_UPDATE">
									<xsl:attribute name="KEY" select="concat($BL, 'TUDF-VESSEL-', $filePosition)"/>
									<UDF_CODE>FIU-VESSEL</UDF_CODE>
									<UDF_VALUE>
										<xsl:value-of select="normalize-space(FileMainCarriage)"/>
									</UDF_VALUE>
								</GEN_UDF_INSTANCE>
								<GEN_UDF_INSTANCE SEARCH_FIELDS="UDF_CODE" ACTION="CREATE_UPDATE">
									<xsl:attribute name="KEY" select="concat($BL, 'TUDF-TOD-', $filePosition)"/>
									<UDF_CODE>FIU-TOD</UDF_CODE>
									<UDF_VALUE>
										<xsl:value-of select="normalize-space(FileUdf/Udf[UdfCode = 'Place-TOD']/UdfValue)"/>									
									</UDF_VALUE>
								</GEN_UDF_INSTANCE>
								<GEN_UDF_INSTANCE SEARCH_FIELDS="UDF_CODE" ACTION="CREATE_UPDATE">
									<xsl:attribute name="KEY" select="concat($BL, 'TUDF-LOYDSN-', $filePosition)"/>
									<UDF_CODE>FIU-LOYDSN</UDF_CODE>
									<UDF_VALUE>
										<xsl:value-of select="normalize-space(FileUdf/Udf[UdfCode = 'NEW-LLOYD']/UdfValue)"/>
									</UDF_VALUE>
								</GEN_UDF_INSTANCE>
								<GEN_UDF_INSTANCE SEARCH_FIELDS="UDF_CODE" ACTION="CREATE_UPDATE">
									<xsl:attribute name="KEY" select="concat($BL, 'TUDF-ETD-', $filePosition)"/>
									<UDF_CODE>FIU-ETD</UDF_CODE>
									<UDF_VALUE>
										<xsl:value-of select="normalize-space(concat(tokenize(FileEtd, '/')[1], '/', tokenize(FileEtd, '/')[2], '/', tokenize(FileEtd, '/')[last()]))"/>
									</UDF_VALUE>
								</GEN_UDF_INSTANCE>
								<GEN_UDF_INSTANCE SEARCH_FIELDS="UDF_CODE" ACTION="CREATE_UPDATE">
									<xsl:attribute name="KEY" select="concat($BL, 'TUDF-ETA-', $filePosition)"/>
									<UDF_CODE>FIU-ETA</UDF_CODE>
									<UDF_VALUE>
										<xsl:value-of select="normalize-space(concat(substring($ETA, 7, 2), '/', substring($ETA, 5, 2), '/', substring($ETA, 1, 4)))"/>
									</UDF_VALUE>
								</GEN_UDF_INSTANCE>
								<GEN_UDF_INSTANCE SEARCH_FIELDS="UDF_CODE" ACTION="CREATE_UPDATE">
									<xsl:attribute name="KEY" select="concat($BL, 'TUDF-POL-', $filePosition)"/>
									<UDF_CODE>FIU-POL</UDF_CODE>
									<UDF_VALUE>
										<xsl:value-of select="FilePortOfLoading"/>
									</UDF_VALUE>
								</GEN_UDF_INSTANCE>
								<GEN_UDF_INSTANCE SEARCH_FIELDS="UDF_CODE" ACTION="CREATE_UPDATE">
									<xsl:attribute name="KEY" select="concat($BL, 'TUDF-POD-', $filePosition)"/>
									<UDF_CODE>FIU-POD</UDF_CODE>
									<UDF_VALUE>
										<xsl:value-of select="FilePortOfDischarge"/>
									</UDF_VALUE>
								</GEN_UDF_INSTANCE>
							</GEN_UDF_INSTANCES>
							<FMSDOM_TRANSPORT_GIETS>
								<xsl:for-each select="//GoodLine">
									<FMSDOM_TRANSPORT_GIET>
										<xsl:attribute name="RELATION_IDENTIFIER">	
											<xsl:value-of select="concat($BL, 'FCO-GO-IT-MAIN-', ID)"/>
										</xsl:attribute>
									</FMSDOM_TRANSPORT_GIET>
								</xsl:for-each>
							</FMSDOM_TRANSPORT_GIETS>
						</FMSDOM_TRANSPORT>
					</xsl:if>
					
					<xsl:if test="string-length(normalize-space($BL)) le 0 and number($filePosition) le 1 and
									(contains($FileTermsOfDelivery, 'CIP') or contains($FileTermsOfDelivery, 'CPT') or 
									 contains($FileTermsOfDelivery, 'DDP') or contains($FileTermsOfDelivery, 'DAP') or 
									 contains($FileTermsOfDelivery, 'DPU'))">
										
						<FMSDOM_TRANSPORT SEARCH_FIELDS="TRANSPORT_MODE" ACTION="CREATE_UPDATE">
							<xsl:attribute name="KEY" select="concat($BL, 'FTR-ON')"/>							
							<TRANSPORT_MODE>ON</TRANSPORT_MODE>
							<TYPE>31</TYPE>
							<TYPEBEHAVIOUR>ROAD</TYPEBEHAVIOUR>
							<FMSDOM_TRANSPORT_STOPS>
								<FMSDOM_TRANSPORT_STOP SEARCH_FIELDS="PLACE_QUALIFIER,HANDLING_TYPE" ACTION="CREATE_UPDATE">
									<xsl:attribute name="KEY" select="concat($BL, 'FTRS-ON-1')"/>
									<HANDLING_TYPE>LOAD</HANDLING_TYPE>
									<SEQUENCE>1</SEQUENCE>
									<PLACE_QUALIFIER>11O</PLACE_QUALIFIER>
									<LOCATION_OWNING_ENTITY>GEN_LOCODES</LOCATION_OWNING_ENTITY>
									<LOCATION_OWNING_CODE>
										<xsl:value-of select="FilePortOfDischarge"/>
									</LOCATION_OWNING_CODE>									
								</FMSDOM_TRANSPORT_STOP>
								<FMSDOM_TRANSPORT_STOP SEARCH_FIELDS="PLACE_QUALIFIER,HANDLING_TYPE" ACTION="CREATE_UPDATE">
									<xsl:attribute name="KEY" select="concat($BL, 'FTRS-ON-2')"/>
									<HANDLING_TYPE>UNLOAD</HANDLING_TYPE>
									<SEQUENCE>2</SEQUENCE>
									<PLACE_QUALIFIER>7</PLACE_QUALIFIER>
									<xsl:choose>
										<xsl:when test="string-length(normalize-space(FileUdf/Udf[upper-case(UdfCode) = 'PLACE-TOD20']/UdfValue)) = 5">
											<LOCATION_OWNING_ENTITY>GEN_LOCODES</LOCATION_OWNING_ENTITY>
											<LOCATION_OWNING_CODE>
												<xsl:value-of select="FileUdf/Udf[upper-case(UdfCode) = 'PLACE-TOD20']/UdfValue"/>
											</LOCATION_OWNING_CODE>
										</xsl:when>
										<xsl:otherwise>
											<LOCATION_NAME>
												<xsl:value-of select="FileUdf/Udf[upper-case(UdfCode) = 'PLACE-TOD']/UdfValue"/>
											</LOCATION_NAME>
										</xsl:otherwise>
									</xsl:choose>						
								</FMSDOM_TRANSPORT_STOP>
							</FMSDOM_TRANSPORT_STOPS>
							<FMSDOM_TRANSPORT_GIETS>
								<xsl:for-each select="//GoodLine">
									<FMSDOM_TRANSPORT_GIET>
										<xsl:attribute name="RELATION_IDENTIFIER">
											<xsl:value-of select="concat($BL, 'FCO-GO-IT-ON-', ID)"/>
										</xsl:attribute>
									</FMSDOM_TRANSPORT_GIET>
								</xsl:for-each>
							</FMSDOM_TRANSPORT_GIETS>
						</FMSDOM_TRANSPORT>
					</xsl:if>
				</FMSDOM_TRANSPORTS>
				<FMSDOM_PARTIES>
					<xsl:if test="$IFTMBF-XML != null and $IFTMBF-XML/IFTMBF/MESSAGE/Group0/Segment_group_10/Name_and_address[Party_function_code_qualifier = 'FP']">
						<FMSDOM_PARTY ACTION="CREATE_UPDATE">
							<xsl:attribute name="KEY" select="concat($BL, 'FPA-IFTMBF-FP-', $filePosition)"/>
							<xsl:attribute name="SEARCH_FIELDS">
								<xsl:choose>
									<xsl:when test="$IFTMBF-XML/IFTMBF/MESSAGE/Group0/Segment_group_10/Name_and_address[Party_function_code_qualifier = 'FP'][1] and 
													upper-case(@Type) != 'TB' and
													string-length(normalize-space(functx:substringOnWholeWords(70, PARTY_NAME/Party_name_-_-1, ' '))) gt 0">
										<xsl:text>PARTY_QUALIFIER,THIRDPARTY_NAME</xsl:text>
									</xsl:when>
									<xsl:otherwise>
										<xsl:text>PARTY_QUALIFIER</xsl:text>
									</xsl:otherwise>
								</xsl:choose>
							</xsl:attribute>
							<PARTY_QUALIFIER>FP</PARTY_QUALIFIER>	
							<ADDRESS_TYPE>
								<xsl:text>OPER</xsl:text>
							</ADDRESS_TYPE>
							<VARIATION>
								<xsl:text>PA</xsl:text>
							</VARIATION>					
							<xsl:for-each select="$IFTMBF-XML/IFTMBF/MESSAGE/Group0/Segment_group_10/Name_and_address[Party_function_code_qualifier = 'FP'][1]">
								<xsl:variable name="partyName" select="functx:substringOnWholeWords(70, PARTY_NAME/Party_name_-_-1, ' ')"/>
								<xsl:variable name="partyCode">
									<xsl:choose>
										<xsl:when test="$company_code = 'FPLES'">
											<xsl:value-of select="concat(PARTY_IDENTIFICATION_DETAILS/Party_identifier, '_FP', '_ES')"/>
										</xsl:when>
										<xsl:when test="$company_code = 'FRACHTITA'">
											<xsl:value-of select="concat(PARTY_IDENTIFICATION_DETAILS/Party_identifier, '_FP', '_IT')"/>
										</xsl:when>
										<xsl:otherwise>
											<xsl:value-of select="concat(PARTY_IDENTIFICATION_DETAILS/Party_identifier, '_FP')"/>
										</xsl:otherwise>
									</xsl:choose>
								</xsl:variable>
								<xsl:if test="upper-case(@Type) != 'TB'">
									<THIRDPARTY_NAME>
										<xsl:choose>
											<xsl:when test="string-length(normalize-space($partyName)) le 0 and string-length(normalize-space($partyCode)) le 0">
												<xsl:text>TBN</xsl:text>
											</xsl:when>
											<xsl:otherwise>
												<xsl:value-of select="$partyName"/>
											</xsl:otherwise>
										</xsl:choose>										
									</THIRDPARTY_NAME>
								</xsl:if>
								<xsl:if test="string-length(normalize-space(PARTY_IDENTIFICATION_DETAILS/Party_identifier)) gt 0">
									<THIRDPARTY_CODE>
										<xsl:value-of select="$partyCode"/>
									</THIRDPARTY_CODE>
								</xsl:if>
								<ADDRESS_STREET>
									<xsl:value-of select="functx:substringOnWholeWords(70, normalize-space(concat(STREET/Street_and_number_or_post_office_box_identifier_-_-1, ' ', STREET/Street_and_number_or_post_office_box_identifier_-_-2, ' ', STREET/Street_and_number_or_post_office_box_identifier_-_-3, ' ', STREET/Street_and_number_or_post_office_box_identifier_-_-4)), ' ')"/>									
								</ADDRESS_STREET>
								<ADDRESS_NAME>
									<xsl:value-of select="functx:substringOnWholeWords(70, PARTY_NAME/Party_name_-_-1, ' ')"/>
								</ADDRESS_NAME>
								<ADDRESS_BUILDING>
									<xsl:value-of select="functx:substringOnWholeWords(70, normalize-space(concat(PARTY_NAME/Party_name_-_-2, ' ', PARTY_NAME/Party_name_-_-3, ' ', PARTY_NAME/Party_name_-_-4)), ' ')"/>									
								</ADDRESS_BUILDING>
								<ADDRESS_COUNTRY>
									<xsl:value-of select="functx:substringOnWholeWords(2, replace(upper-case(Country_identifier), 'ZZ', ''), ' ')"/>
								</ADDRESS_COUNTRY>
								<ADDRESS_POSTAL_CODE>
									<xsl:value-of select="functx:substringOnWholeWords(17, Postal_identification_code, ' ')"/>									
								</ADDRESS_POSTAL_CODE>
								<ADDRESS_CITY>
									<xsl:value-of select="functx:substringOnWholeWords(70, City_name, ' ')"/>
								</ADDRESS_CITY>
								<PARTY_FORMATTED>
									<xsl:value-of select="functx:lineFeedOnWholeWords(35, PARTY_NAME/Party_name_-_-1, ' ')"/>
									<xsl:text>&#10;</xsl:text>
									<xsl:value-of select="functx:lineFeedOnWholeWords(35, normalize-space(concat(STREET/Street_and_number_or_post_office_box_identifier_-_-1, ' ', STREET/Street_and_number_or_post_office_box_identifier_-_-2, ' ', STREET/Street_and_number_or_post_office_box_identifier_-_-3, ' ', STREET/Street_and_number_or_post_office_box_identifier_-_-4)), ' ')"/>									
									<xsl:text>&#10;</xsl:text>
									<xsl:variable name="country" select="upper-case(Country_identifier)"/>
									<xsl:value-of select="functx:lineFeedOnWholeWords(35, normalize-space(concat(Postal_identification_code, ' ', City_name, ' ', $countryCodesAndNames/TRIS_DATA_UPDATE/GEN_COUNTRIES/GEN_COUNTRY[CODE = $country]/NAME)), ' ')"/>
								</PARTY_FORMATTED>
							</xsl:for-each>
						</FMSDOM_PARTY>
					</xsl:if>
					<FMSDOM_PARTY ACTION="CREATE_UPDATE">
						<xsl:attribute name="KEY" select="concat($BL, 'FPA-TM-', $filePosition)"/>
						<xsl:attribute name="SEARCH_FIELDS">
							<xsl:choose>
								<xsl:when test="string-length(normalize-space(functx:substringOnWholeWords(70, FileUdf/Udf[UdfCode = 'Sped-CTA']/UdfValue, ' '))) gt 0">
									<xsl:text>PARTY_QUALIFIER,THIRDPARTY_NAME</xsl:text>
								</xsl:when>
								<xsl:otherwise>
									<xsl:text>PARTY_QUALIFIER</xsl:text>
								</xsl:otherwise>
							</xsl:choose>
						</xsl:attribute>
						<PARTY_QUALIFIER>TM</PARTY_QUALIFIER>
						<ADDRESS_TYPE>
							<xsl:text>OPER</xsl:text>
						</ADDRESS_TYPE>
						<VARIATION>
							<xsl:text>PA</xsl:text>
						</VARIATION>
						<THIRDPARTY_NAME>
							<xsl:variable name="partyName" select="functx:substringOnWholeWords(70, FileUdf/Udf[UdfCode = 'Sped-CTA']/UdfValue, ' ')"/>
							<xsl:choose>
								<xsl:when test="string-length(normalize-space($partyName)) le 0">
									<xsl:text>TBN</xsl:text>
								</xsl:when>
								<xsl:otherwise>
									<xsl:value-of select="$partyName"/>
								</xsl:otherwise>
							</xsl:choose>
						</THIRDPARTY_NAME>
						<CONTACT_TEL>
							<xsl:value-of select="functx:substringOnWholeWords(100, FileUdf/Udf[UdfCode = 'Sped-TEL']/UdfValue, ' ')"/>
						</CONTACT_TEL>
						<CONTACT_FAX>
							<xsl:value-of select="functx:substringOnWholeWords(100, FileUdf/Udf[UdfCode = 'Sped-FAX']/UdfValue, ' ')"/>
						</CONTACT_FAX>
						<CONTACT_EMAIL>
							<xsl:value-of select="functx:substringOnWholeWords(100, FileUdf/Udf[UdfCode = 'Sped-EMAIL']/UdfValue, ' ')"/>							
						</CONTACT_EMAIL>
					</FMSDOM_PARTY>
					<xsl:if test="count(//GoodDangerousGoodsNotifications/DangerousGoodsNotification) gt 0">
						<FMSDOM_PARTY ACTION="CREATE_UPDATE">
							<xsl:attribute name="KEY" select="concat($BL, 'FPA-DG-', $filePosition)"/>
							<xsl:attribute name="SEARCH_FIELDS"><xsl:text>PARTY_QUALIFIER</xsl:text></xsl:attribute>
							<PARTY_QUALIFIER>DG</PARTY_QUALIFIER>
							<VARIATION>PA</VARIATION>
							<THIRDPARTY_CODE>
								<xsl:choose>
									<xsl:when test="$company_code = 'FPLES'">
										<xsl:text>DG_ES</xsl:text>
									</xsl:when>
									<xsl:when test="$company_code = 'FRACHTITA'">
										<xsl:text>DG_IT</xsl:text>
									</xsl:when>
									<xsl:otherwise>
										<xsl:text>DG</xsl:text>
									</xsl:otherwise>
								</xsl:choose>
							</THIRDPARTY_CODE>
						</FMSDOM_PARTY>
					</xsl:if>
					<xsl:for-each-group select="FileParties/Party[@Type != 'AG' and (PartyId != '' or PartyDescription != '')]" group-by="concat(PartyDescription, '-', @Type, '-', PartyId[1])">
						<xsl:variable name="partyPosition" select="position()"/>
						<xsl:variable name="ParytID">
							<xsl:choose>
								<xsl:when test="string-length(normalize-space(tokenize(PartyId[1], '_')[1])) le 0">
									<xsl:text>EMPTY</xsl:text>
								</xsl:when>
								<xsl:otherwise>
									<xsl:value-of select="tokenize(PartyId[1], '_')[1]"/>
								</xsl:otherwise>
							</xsl:choose>
						</xsl:variable>
						<xsl:if test="not(contains('293534,2683269,5904903', $ParytID) and contains(upper-case(PartyId[1]), 'NOTCA')) and 
									  not(upper-case(@Type) = 'CA' and contains('ERST_UP;ABSC_CR;ABSC_UP', $SERVICE_CODE) and contains('FPLES;FRACHTITA', $company_code)) or 
									  upper-case(@Type) = 'BL'">
							<FMSDOM_PARTY ACTION="CREATE_UPDATE">
								<xsl:choose>
									<xsl:when test="upper-case(@Type) = 'CA' or upper-case(@Type) = 'EP'">
										<xsl:attribute name="KEY">
											<xsl:if test="string-length(normalize-space($BL)) gt 0">
												<xsl:text>1</xsl:text>
											</xsl:if>
											<xsl:value-of select="concat('9999', $filePosition, $partyPosition)"/>
										</xsl:attribute>
									</xsl:when>
									<xsl:otherwise>
										<xsl:attribute name="KEY" select="concat($BL, 'FPA-', $filePosition, '-', $partyPosition)"/>
									</xsl:otherwise>
								</xsl:choose>
								<xsl:attribute name="SEARCH_FIELDS">
									<xsl:choose>
										<xsl:when test="upper-case(@Type) = 'DO' or upper-case(@Type) = 'OS' or upper-case(@Type) = 'N1' or upper-case(@Type) = 'N2'">
											<xsl:text>PARTY_QUALIFIER</xsl:text>
										</xsl:when>
										<xsl:when test="not(contains('293534,2683269,5904903,2274178', $ParytID) or (contains('817630,300606,300627', $ParytID) and upper-case(@Type) = 'CA')) or upper-case(@Type) = 'BL' and 
														string-length(normalize-space(functx:substringOnWholeWords(70, PartyDescription, ' '))) gt 0">
											<xsl:text>PARTY_QUALIFIER,THIRDPARTY_NAME</xsl:text>
										</xsl:when>
										<xsl:otherwise>
											<xsl:text>PARTY_QUALIFIER</xsl:text>
										</xsl:otherwise>
									</xsl:choose>
								</xsl:attribute>
								<xsl:variable name="partyName" select="functx:substringOnWholeWords(70, PartyDescription, ' ')"/>
								<xsl:variable name="partyCode">
									<xsl:variable name="code">
										<xsl:if test="$company_code = 'FPLES'">
											<xsl:text>_ES</xsl:text>
										</xsl:if>
										<xsl:if test="$company_code = 'FRACHTITA'">
											<xsl:text>_IT</xsl:text>
										</xsl:if>
									</xsl:variable>
									<xsl:choose>
										<xsl:when test="contains(PartyId[1], '817630') and upper-case(@Type) = 'CA'">
											<xsl:value-of select="concat(PartyId[1], '_', $POL, $code)"/>
										</xsl:when>
										<xsl:when test="contains(PartyId[1], '300606') and upper-case(@Type) = 'CA'">
											<xsl:value-of select="concat(PartyId[1], '_', $partyID_CZ , '_', substring($POD, 1, 2)), $code"/>
										</xsl:when>
										<xsl:when test="contains(PartyId[1], '300627') and upper-case(@Type) = 'CA'">
											<xsl:value-of select="concat(PartyId[1], '_', $partyID_CZ), $code"/>
										</xsl:when>
										<xsl:otherwise>
											<xsl:value-of select="concat(PartyId[1], $code)"/>
										</xsl:otherwise>
									</xsl:choose>
								</xsl:variable>
								<xsl:if test="(@Type = 'FP' or not(contains(upper-case(PartyId[1]), 'NOTCA'))) and string-length(normalize-space(PartyId[1])) gt 0">
									<THIRDPARTY_CODE>
										<xsl:value-of select="$partyCode"/>
									</THIRDPARTY_CODE>
								</xsl:if>
								<PARTY_QUALIFIER>
									<xsl:choose>
										<xsl:when test="upper-case(@Type) = 'BL'">
											<xsl:value-of select="replace(replace(replace(concat(@Type, PartyId[1]), '_NotCA', ''), '_EP', ''), '_CA', '')"/>
										</xsl:when>
										<xsl:otherwise>
											<xsl:value-of select="@Type"/>
										</xsl:otherwise>
									</xsl:choose>
								</PARTY_QUALIFIER>
								<VARIATION>
									<xsl:text>PA</xsl:text>
								</VARIATION>
								<xsl:if test="not(contains('293534,2683269,5904903,2274178', $ParytID) or (contains('817630,300606,300627', $ParytID) and upper-case(@Type) = 'CA')) or upper-case(@Type) = 'BL'">
									<ADDRESS_TYPE>
										<xsl:text>OPER</xsl:text>
									</ADDRESS_TYPE>
									<xsl:if test="string-length(normalize-space(PartyReference)) gt 0">
										<REFERENCE>
											<xsl:value-of select="functx:substringOnWholeWords(20, PartyReference, ' ')"/>
										</REFERENCE>
										<REFERENCE_QUALIFIER>GEN</REFERENCE_QUALIFIER>
									</xsl:if>
									<THIRDPARTY_NAME>
										<xsl:choose>
											<xsl:when test="string-length(normalize-space($partyName)) le 0 and string-length(normalize-space($partyCode)) le 0">
												<xsl:text>TBN</xsl:text>
											</xsl:when>
											<xsl:otherwise>
												<xsl:value-of select="$partyName"/>
											</xsl:otherwise>
										</xsl:choose>
									</THIRDPARTY_NAME>
									<ADDRESS_STREET>
										<xsl:value-of select="functx:substringOnWholeWords(70, PartyAddressName, ' ')"/>
									</ADDRESS_STREET>
									<ADDRESS_NAME>
										<xsl:value-of select="functx:substringOnWholeWords(70, PartyAddressName1, ' ')"/>
									</ADDRESS_NAME>
									<ADDRESS_BUILDING>
										<xsl:value-of select="functx:substringOnWholeWords(70, PartyAddressName2, ' ')"/>
									</ADDRESS_BUILDING>
									<ADDRESS_COUNTRY>
										<xsl:value-of select="functx:substringOnWholeWords(2, replace(upper-case(PartyAddressCountry), 'ZZ', ''), ' ')"/>
									</ADDRESS_COUNTRY>
									<ADDRESS_POSTAL_CODE>
										<xsl:value-of select="functx:substringOnWholeWords(17, substring(PartyAddressZipcode, 1, 17), ' ')"/>
									</ADDRESS_POSTAL_CODE>
									<ADDRESS_CITY>
										<xsl:value-of select="functx:substringOnWholeWords(70, PartyAddressCity, ' ')"/>
									</ADDRESS_CITY>
									<CONTACT_TEL>
										<xsl:value-of select="functx:substringOnWholeWords(100, PartyContactTelephone, ' ')"/>
									</CONTACT_TEL>
									<CONTACT_FAX>
										<xsl:if test="normalize-space(upper-case(PartyContactFax)) != 'AS AGENTS ONLY'">
											<xsl:value-of select="functx:substringOnWholeWords(100, PartyContactFax, ' ')"/>
										</xsl:if>
									</CONTACT_FAX>
									<CONTACT_EMAIL>
										<xsl:value-of select="functx:substringOnWholeWords(100, PartyLetterOfCredit1, ' ')"/>
									</CONTACT_EMAIL>
									<PARTY_FORMATTED>
										<xsl:variable name="value">
											<xsl:choose>
												<xsl:when test="string-length(normalize-space(PartyAddressName1)) le 0">
													<xsl:value-of select="functx:lineFeedOnWholeWords(35, PartyDescription, ' ')"/>
												</xsl:when>
												<xsl:otherwise>
													<xsl:value-of select="functx:lineFeedOnWholeWords(35, PartyAddressName1, ' ')"/>
												</xsl:otherwise>
											</xsl:choose>
											<xsl:text>&#10;</xsl:text>
											<xsl:if test="string-length(normalize-space(PartyAddressName2)) gt 0">
												<xsl:value-of select="functx:lineFeedOnWholeWords(35, PartyAddressName2, ' ')"/>
												<xsl:text>&#10;</xsl:text>
											</xsl:if>
											<xsl:if test="string-length(normalize-space(PartyAddressName3)) gt 0">
												<xsl:value-of select="functx:lineFeedOnWholeWords(35, PartyAddressName3, ' ')"/>
												<xsl:text>&#10;</xsl:text>
											</xsl:if>
											<xsl:value-of select="functx:lineFeedOnWholeWords(35, PartyAddressName, ' ')"/>
											<xsl:text>&#10;</xsl:text>
											<xsl:variable name="country" select="upper-case(PartyAddressCountry)"/>
											<xsl:value-of select="functx:lineFeedOnWholeWords(35, normalize-space(concat(PartyAddressZipcode, ' ', PartyAddressCity, ' ', $countryCodesAndNames/TRIS_DATA_UPDATE/GEN_COUNTRIES/GEN_COUNTRY[CODE = $country]/NAME)), ' ')"/>						
											<xsl:if test="string-length(normalize-space(PartyContactTelephone)) gt 0">
												<xsl:text>&#10;</xsl:text>
												<xsl:value-of select="functx:lineFeedOnWholeWords(35, concat('Tel: ', PartyContactTelephone), ' ')"/>
											</xsl:if>
											<xsl:if test="string-length(normalize-space(PartyContactFax)) gt 0 and normalize-space(upper-case(PartyContactFax)) != 'AS AGENTS ONLY'">
												<xsl:text>&#10;</xsl:text>
												<xsl:value-of select="functx:lineFeedOnWholeWords(35, concat('Fax: ', PartyContactFax), ' ')"/>
											</xsl:if>
											<xsl:if test="string-length(normalize-space(PartyContactFax)) gt 0 and normalize-space(upper-case(PartyContactFax)) = 'AS AGENTS ONLY'">
												<xsl:text>&#10;</xsl:text>
												<xsl:value-of select="functx:lineFeedOnWholeWords(35, PartyContactFax, ' ')"/>
											</xsl:if>
											<xsl:if test="string-length(normalize-space(PartyLetterOfCredit1)) gt 0">
												<xsl:text>&#10;</xsl:text>
												<xsl:value-of select="functx:lineFeedOnWholeWords(35, concat('Email: ', PartyLetterOfCredit1), ' ')"/>
											</xsl:if>
											<xsl:if test="contains(upper-case(@Type), 'OS')">
												<xsl:text>&#10;</xsl:text>
												<xsl:value-of select="../../FileCustomerReference"/>
											</xsl:if>									
										</xsl:variable>
										<xsl:choose>
											<xsl:when test="upper-case(@Type) = 'OS' or upper-case(@Type) = 'DO' or upper-case(@Type) = 'N1' or upper-case(@Type) = 'N2'">
												<xsl:variable name="numberOfTokens" select="count(tokenize($value, '&#10;'))"/>
												<xsl:for-each select="tokenize($value, '&#10;')">
													<xsl:choose>
														<xsl:when test="position() le 6">
															<xsl:value-of select="."/>
															<xsl:if test="position() lt 6 and position() lt $numberOfTokens">
																<xsl:text>&#10;</xsl:text>
															</xsl:if>
														</xsl:when>
													</xsl:choose>
												</xsl:for-each>
											</xsl:when>
											<xsl:otherwise>
												<xsl:value-of select="$value"/>
											</xsl:otherwise>
										</xsl:choose>
									</PARTY_FORMATTED>
								</xsl:if>
							</FMSDOM_PARTY>
						</xsl:if>
					</xsl:for-each-group>
				</FMSDOM_PARTIES>
				<xsl:if test="	(number($filePosition) gt 1 and string-length(normalize-space($MBLorRBL)) gt 0) or 
								(number($filePosition) le 1 and string-length(normalize-space($MBLorRBL)) le 0) or 
								(number($filePosition) le 1 and string-length(normalize-space($MBLorRBL)) gt 0 and string-length(normalize-space($BL)) gt 0)">
					<FMSDOM_GOODS>					
						<xsl:if test="$SERVICE_CODE != 'ERST_CR'">
							<xsl:attribute name="ACTION">
								<xsl:text>DELETE_NOT_CU</xsl:text>
							</xsl:attribute>						
						</xsl:if>
						<xsl:for-each-group select="//FileGoodLines/GoodLine" group-by="GoodCustomerReference">
							<xsl:variable name="goodGroup" select="position()"/>
							<xsl:for-each select="current-group()">
								<xsl:variable name="goodPosition" select="position()"/>
								<FMSDOM_GOOD ACTION="CREATE_UPDATE" SEARCH_FIELDS="TECHNICAL_REFERENCE">
									<xsl:attribute name="KEY" select="concat($BL, 'FGO-', $filePosition, '-', $goodGroup, '-', $goodPosition, '-', position())"/>	
									<xsl:if test="string-length(normalize-space(GoodCustomerReference)) gt 0">
										<TECHNICAL_REFERENCE>
											<xsl:value-of select="concat(GoodCustomerReference, '-', position())"/>
										</TECHNICAL_REFERENCE>
										<BOOKING_REFERENCE>
											<xsl:value-of select="GoodCustomerReference"/>
										</BOOKING_REFERENCE>
										<REFERENCE_QUALIFIER>
											<xsl:value-of select="GoodReference/@Qualifier"/>
										</REFERENCE_QUALIFIER>
									</xsl:if>
									<REFERENCE>
										<xsl:value-of select="GoodReference"/>
									</REFERENCE>
									<HS_CODE>
										<xsl:value-of select="GoodStatisticalCode"/>
									</HS_CODE>
									<NUMBER_OF_PACKAGES>
										<xsl:choose>
											<!--Test Goodswitch-->
											<xsl:when test="(contains('PE,GT,SV', normalize-space(upper-case(../../FileReserveFields/ReserveField4))) or $FCLorLCL = 'LCL' or ($MBLorRBL = 'MBL' or $MBLorRBL = 'RBLasMBL')) and number(replace(string(number(GoodUdf/Udf[UdfCode = 'GIDnrPackages1']/UdfValue)), 'NaN', '0')) gt 0">
												<xsl:value-of select="GoodUdf/Udf[UdfCode = 'GIDnrPackages1']/UdfValue"/>
											</xsl:when>
											<xsl:when test="string-length(normalize-space(GoodNumberOfPieces)) le 0">
												<xsl:text>1</xsl:text>
											</xsl:when>
											<xsl:otherwise>
												<xsl:value-of select="GoodNumberOfPieces"/>
											</xsl:otherwise>
										</xsl:choose>								
									</NUMBER_OF_PACKAGES>
									<PACKAGE_CODE>
										<xsl:choose>
											<!--Test Goodswitch-->
											<xsl:when test="(contains('PE,GT,SV', normalize-space(upper-case(../../FileReserveFields/ReserveField4))) or $FCLorLCL = 'LCL' or ($MBLorRBL = 'MBL' or $MBLorRBL = 'RBLasMBL')) and number(replace(string(number(GoodUdf/Udf[UdfCode = 'GIDnrPackages1']/UdfValue)), 'NaN', '0')) gt 0">
												<xsl:value-of select="GoodUdf/Udf[UdfCode = 'Packing1']/UdfValue"/>
											</xsl:when>
											<xsl:when test="string-length(normalize-space(GoodNumberOfPieces/@Unit)) le 0">
												<xsl:text>BULK</xsl:text>
											</xsl:when>
											<xsl:otherwise>
												<xsl:value-of select="GoodNumberOfPieces/@Unit"/>
											</xsl:otherwise>
										</xsl:choose>									
									</PACKAGE_CODE>
									<GROSS_WEIGHT>
										<xsl:value-of select="replace(format-number(number(GoodGrossWeight), '#.000'), 'NaN', '')"/>
									</GROSS_WEIGHT>
									<NET_WEIGHT>
										<xsl:value-of select="replace(format-number(number(GoodNettWeight), '#.000'), 'NaN', '')"/>
									</NET_WEIGHT>
									<VOLUME>
										<xsl:value-of select="replace(format-number(number(GoodVolume), '#.000'), 'NaN', '')"/>
									</VOLUME>
									<VOLUME_WEIGHT>
										<xsl:choose>
											<xsl:when test="number(GoodGrossWeight) div 1000 gt number(GoodVolume)">
												<xsl:value-of select="replace(format-number(number(GoodGrossWeight) div 1000, '#.000'), 'NaN', '')"/>
											</xsl:when>
											<xsl:otherwise>
												<xsl:value-of select="replace(format-number(number(GoodVolume), '#.000'), 'NaN', '')"/>
											</xsl:otherwise>
										</xsl:choose>
									</VOLUME_WEIGHT>
										<VOLUME_WEIGHT_UNIT>MT</VOLUME_WEIGHT_UNIT>
									<GROSS_WEIGHT_UNIT>KG</GROSS_WEIGHT_UNIT>
									<NET_WEIGHT_UNIT>KG</NET_WEIGHT_UNIT>
									<VOLUME_UNIT>CBM</VOLUME_UNIT>
									<CARGO_DESCRIPTION>
										<xsl:choose>
											<xsl:when test="string-length(normalize-space(concat(GoodUdf/Udf[UdfCode = 'GIDnrPackages2']/UdfValue, ' ',  GoodUdf/Udf[UdfCode = 'GIDrespAgency2']/UdfValue))) le 0 and string-length(normalize-space(concat(GoodUdf/Udf[UdfCode = 'GIDnrPackages3']/UdfValue, ' ',  GoodUdf/Udf[UdfCode = 'GIDrespAgency3']/UdfValue))) le 0">
												<xsl:comment>Single Level</xsl:comment>
												<xsl:if test="string-length(normalize-space(GoodUdf/Udf[UdfCode = 'GIDrespAgency1']/UdfValue)) gt 0">
													<xsl:value-of select="functx:lineFeedOnWholeWords(35, normalize-space(GoodUdf/Udf[UdfCode = 'GIDrespAgency1']/UdfValue), ' ')"/>
												</xsl:if>
											</xsl:when>
											<xsl:when test="(contains('PE,GT,SV', normalize-space(upper-case(../../FileReserveFields/ReserveField4))) or $FCLorLCL = 'LCL' or ($MBLorRBL = 'MBL' or $MBLorRBL = 'RBLasMBL')) and number(replace(string(number(GoodUdf/Udf[UdfCode = 'GIDnrPackages1']/UdfValue)), 'NaN', '0')) gt 0">
												<xsl:comment>GoodSwitch</xsl:comment>
												<xsl:if test="string-length(normalize-space(GoodUdf/Udf[UdfCode = 'GIDrespAgency1']/UdfValue)) gt 0">
													<xsl:value-of select="functx:lineFeedOnWholeWords(35, normalize-space(GoodUdf/Udf[UdfCode = 'GIDrespAgency1']/UdfValue), ' ')"/>
												</xsl:if>
												<xsl:if test="string-length(normalize-space(concat(GoodUdf/Udf[UdfCode = 'GIDnrPackages2']/UdfValue, ' ',  GoodUdf/Udf[UdfCode = 'GIDrespAgency2']/UdfValue))) gt 0">
													<xsl:text>&#10;</xsl:text><xsl:value-of select="functx:lineFeedOnWholeWords(35, normalize-space(concat(GoodUdf/Udf[UdfCode = 'GIDnrPackages2']/UdfValue, ' ',  GoodUdf/Udf[UdfCode = 'GIDrespAgency2']/UdfValue)), ' ')"/>
												</xsl:if>
												<xsl:if test="string-length(normalize-space(concat(GoodUdf/Udf[UdfCode = 'GIDnrPackages3']/UdfValue, ' ',  GoodUdf/Udf[UdfCode = 'GIDrespAgency3']/UdfValue))) gt 0">
													<xsl:text>&#10;</xsl:text><xsl:value-of select="functx:lineFeedOnWholeWords(35, normalize-space(concat(GoodUdf/Udf[UdfCode = 'GIDnrPackages3']/UdfValue, ' ',  GoodUdf/Udf[UdfCode = 'GIDrespAgency3']/UdfValue)), ' ')"/>
												</xsl:if>
											</xsl:when>
											<xsl:otherwise>
												<xsl:comment>NO GoodSwitch</xsl:comment>
												<xsl:if test="string-length(normalize-space(GoodUdf/Udf[UdfCode = 'GIDrespAgency2']/UdfValue)) gt 0">
													<xsl:value-of select="functx:lineFeedOnWholeWords(35, normalize-space(GoodUdf/Udf[UdfCode = 'GIDrespAgency2']/UdfValue), ' ')"/>
												</xsl:if>
												<xsl:if test="string-length(normalize-space(concat(GoodUdf/Udf[UdfCode = 'GIDnrPackages1']/UdfValue, ' ',  GoodUdf/Udf[UdfCode = 'GIDrespAgency1']/UdfValue))) gt 0">
													<xsl:text>&#10;</xsl:text><xsl:value-of select="functx:lineFeedOnWholeWords(35, normalize-space(concat(GoodUdf/Udf[UdfCode = 'GIDnrPackages1']/UdfValue, ' ',  GoodUdf/Udf[UdfCode = 'GIDrespAgency1']/UdfValue)), ' ')"/>
												</xsl:if>
												<xsl:if test="string-length(normalize-space(concat(GoodUdf/Udf[UdfCode = 'GIDnrPackages3']/UdfValue, ' ',  GoodUdf/Udf[UdfCode = 'GIDrespAgency3']/UdfValue))) gt 0">
													<xsl:text>&#10;</xsl:text><xsl:value-of select="functx:lineFeedOnWholeWords(35, normalize-space(concat(GoodUdf/Udf[UdfCode = 'GIDnrPackages3']/UdfValue, ' ',  GoodUdf/Udf[UdfCode = 'GIDrespAgency3']/UdfValue)), ' ')"/>
												</xsl:if>										
											</xsl:otherwise>
										</xsl:choose>
										<xsl:if test="string-length(normalize-space(GoodUdf/Udf[UdfCode = 'FTX-AAA']/UdfValue)) gt 0">
											<xsl:text>&#10;</xsl:text><xsl:value-of select="functx:lineFeedOnWholeWords(35, normalize-space(GoodUdf/Udf[UdfCode = 'FTX-AAA']/UdfValue), ' ')"/>
										</xsl:if>
										<xsl:if test="string-length(normalize-space(GoodUdf/Udf[UdfCode = 'FTX-AAS']/UdfValue)) gt 0">	
											<xsl:text>&#10;</xsl:text><xsl:value-of select="functx:lineFeedOnWholeWords(35, normalize-space(GoodUdf/Udf[UdfCode = 'FTX-AAS']/UdfValue), ' ')"/>
										</xsl:if>
										<xsl:if test="string-length(normalize-space(GoodUdf/Udf[UdfCode = 'BUYORDNR']/UdfValue)) gt 0">
											<xsl:text>&#10;</xsl:text><xsl:value-of select="functx:lineFeedOnWholeWords(35, normalize-space(GoodUdf/Udf[UdfCode = 'BUYORDNR']/UdfValue), ' ')"/>
										</xsl:if>
										<xsl:if test="string-length(normalize-space(GoodUdf/Udf[UdfCode = 'RFF-VN']/UdfValue)) gt 0">
											<xsl:text>&#10;</xsl:text><xsl:value-of select="functx:lineFeedOnWholeWords(35, normalize-space(GoodUdf/Udf[UdfCode = 'RFF-VN']/UdfValue), ' ')"/>
										</xsl:if>
										<xsl:if test="string-length(normalize-space(GoodUdf/Udf[UdfCode = 'FTX-AAC']/UdfValue)) gt 0">
											<xsl:text>&#10;</xsl:text><xsl:value-of select="normalize-space(GoodUdf/Udf[UdfCode = 'FTX-AAC']/UdfValue)"/>
										</xsl:if>
										<xsl:if test="string-length(normalize-space(GoodDangerousGoodsNotifications/DangerousGoodsNotification/ImoEmsNumber)) gt 0">
											<xsl:text>&#10;</xsl:text><xsl:value-of select="concat('EMS: ', normalize-space(GoodDangerousGoodsNotifications/DangerousGoodsNotification/ImoEmsNumber))"/>
										</xsl:if>
										<xsl:if test="string-length(normalize-space(GoodDangerousGoodsNotifications/DangerousGoodsNotification/ImoFlashpointActual)) gt 0">
											<xsl:text>&#10;</xsl:text><xsl:value-of select="concat('Flashpoint: ', normalize-space(concat(GoodDangerousGoodsNotifications/DangerousGoodsNotification/ImoFlashpointActual, ' ', substring(GoodDangerousGoodsNotifications/DangerousGoodsNotification/ImoFlashpointActualQualifier, 1, 1))))"/>
										</xsl:if>
									</CARGO_DESCRIPTION>
									<MARKS_AND_NUMBERS>
										<xsl:for-each select="GoodMarksAndNumbers/MarksAndNumbers">
											<xsl:value-of select="functx:lineFeedOnWholeWords(17, replace(normalize-space(MarksMarkAndNumber), ' / ', '/'), ' ')"/>
											<xsl:if test="position() != last()">
												<xsl:text>&#10;</xsl:text>
											</xsl:if>
										</xsl:for-each>
									</MARKS_AND_NUMBERS>
									<xsl:if test="count(GoodUdf/Udf[	UdfCode != 'COMMODITYG' 	and UdfCode != 'FTX-PRD'	and UdfCode != 'FTX-DIN'  	and UdfCode != 'RFF-ABT'  and
																		UdfCode != 'LOCNR'			and UdfCode != 'RFF-LC'		and UdfCode != 'FTX-PKG'  	and UdfCode != 'IMPLICNR' and
																		UdfCode != 'RFF-AKD'		and UdfCode != 'RFF-IP'		and UdfCode != 'SRVYREFNR'	and UdfCode != 'FTX-HAN'  and UdfCode != 'FTX-AEB'  and
																		UdfCode != 'FTX-COI'		and UdfCode != 'FTX-AHA'	and UdfCode != 'FTX-AHA2'	and UdfCode != 'FTX-AAC2' and UdfCode != 'FTX-AQV']) gt 0">
										<GEN_UDF_INSTANCES>
											<xsl:for-each-group select="GoodUdf/Udf[	UdfCode != 'COMMODITYG'	and UdfCode != 'FTX-PRD'	and UdfCode != 'FTX-DIN'  	and UdfCode != 'RFF-ABT'  and
																						UdfCode != 'LOCNR'		and UdfCode != 'RFF-LC'		and UdfCode != 'FTX-PKG'  	and UdfCode != 'IMPLICNR' and
																						UdfCode != 'RFF-AKD'	and UdfCode != 'RFF-IP'		and UdfCode != 'SRVYREFNR'	and UdfCode != 'FTX-HAN'  and UdfCode != 'FTX-AEB'  and
																						UdfCode != 'FTX-COI'	and UdfCode != 'FTX-AHA'	and UdfCode != 'FTX-AHA2'	and UdfCode != 'FTX-AAC2' and UdfCode != 'FTX-AQV']" group-by="UdfCode">
												<xsl:variable name="udfPosition" select="position()"/>
												<xsl:for-each select="current-group()[last()]">
													<xsl:choose>
														<xsl:when test="contains(UdfCode, 'FTX-LOI') or contains(UdfCode, 'FTX-DEL')">
															<xsl:variable name="udf-1">
																<xsl:value-of select="functx:substringOnWholeWords(500, UdfValue, ' ')"/>
															</xsl:variable>
															<xsl:variable name="udf-2">
																<xsl:if test="string-length($udf-1) gt 0">
																	<xsl:value-of select="functx:substringOnWholeWords(500, substring-after(UdfValue, $udf-1), ' ')"/>
																</xsl:if>
															</xsl:variable>	
															<GEN_UDF_INSTANCE SEARCH_FIELDS="UDF_CODE" ACTION="CREATE_UPDATE">
																<xsl:attribute name="KEY" select="concat($BL, 'GUDF-', $filePosition, '-', $goodGroup, '-', $goodPosition, '-', $udfPosition, '-', position(), '-1')"/>														
																<UDF_CODE>
																	<xsl:choose>
																		<xsl:when test="starts-with(UdfCode, 'FTX') or starts-with(UdfCode, 'RFF')">
																			<xsl:value-of select="concat('GO_', UdfCode, '1')"/>
																		</xsl:when>
																		<xsl:otherwise>
																			<xsl:value-of select="UdfCode"/>
																		</xsl:otherwise>
																	</xsl:choose>
																</UDF_CODE>
																<UDF_VALUE>
																	<xsl:value-of select="normalize-space(string($udf-1))"/>															
																</UDF_VALUE>												
															</GEN_UDF_INSTANCE>
															<GEN_UDF_INSTANCE SEARCH_FIELDS="UDF_CODE" ACTION="CREATE_UPDATE">
																<xsl:attribute name="KEY" select="concat($BL, 'GUDF-', $filePosition, '-', $goodGroup, '-', $goodPosition, '-', $udfPosition, '-', position(), '-2')"/>														
																<UDF_CODE>
																	<xsl:choose>
																		<xsl:when test="starts-with(UdfCode, 'FTX') or starts-with(UdfCode, 'RFF')">
																			<xsl:value-of select="concat('GO_', UdfCode, '2')"/>
																		</xsl:when>
																		<xsl:otherwise>
																			<xsl:value-of select="UdfCode"/>
																		</xsl:otherwise>
																	</xsl:choose>
																</UDF_CODE>
																<UDF_VALUE>
																	<xsl:value-of select="normalize-space(string($udf-2))"/>	
																</UDF_VALUE>												
															</GEN_UDF_INSTANCE>
														</xsl:when>
														<xsl:otherwise>
															<GEN_UDF_INSTANCE SEARCH_FIELDS="UDF_CODE" ACTION="CREATE_UPDATE">
																<xsl:attribute name="KEY" select="concat($BL, 'GUDF-', $filePosition, '-', $goodGroup, '-', $goodPosition, '-', $udfPosition, '-', position(), '-3')"/>														
																<UDF_CODE>
																	<xsl:choose>
																		<xsl:when test="starts-with(UdfCode, 'FTX') or starts-with(UdfCode, 'RFF')">
																			<xsl:value-of select="concat('GO_', UdfCode)"/>
																		</xsl:when>
																		<xsl:otherwise>
																			<xsl:value-of select="UdfCode"/>
																		</xsl:otherwise>
																	</xsl:choose>
																</UDF_CODE>
																<UDF_VALUE>
																	<xsl:value-of select="normalize-space(substring(UdfValue, 1, 500))"/>
																</UDF_VALUE>												
															</GEN_UDF_INSTANCE>
														</xsl:otherwise>
													</xsl:choose>											
												</xsl:for-each>
											</xsl:for-each-group>
										</GEN_UDF_INSTANCES>
									</xsl:if>
									<xsl:if test="count(GoodDangerousGoodsNotifications/DangerousGoodsNotification) gt 0">
										<FMSDOM_DANGEROUS_GOODS>
											<xsl:for-each select="GoodDangerousGoodsNotifications/DangerousGoodsNotification">
												<xsl:variable name="dangerousGoodPosition" select="position()"/>
												<FMSDOM_DANGEROUS_GOOD ACTION="CREATE_UPDATE" SEARCH_FIELDS="UNDG_CODE">
													<xsl:attribute name="KEY" select="concat($BL, 'FGO-DG-', $filePosition, '-', $goodGroup, '-', $goodPosition, '-', $dangerousGoodPosition, '-', position())"/>	
													<EMS_NUMBER>
														<xsl:value-of select="ImoEmsNumber"/>
													</EMS_NUMBER>
													<FLASH_POINT>
														<xsl:value-of select="translate(ImoFlashpointActual, 'cCfFkK°', '')"/>
													</FLASH_POINT>
													<FLASH_POINT_UNIT>
														<xsl:choose>
															<xsl:when test="string-length(normalize-space(translate(ImoFlashpointActual, '0123456789°-+', ''))) gt 0">
																<xsl:value-of select="translate(ImoFlashpointActual, '0123456789°-+', '')"/>
															</xsl:when>
															<xsl:otherwise>
																<xsl:value-of select="ImoFlashpointActualQualifier"/>
															</xsl:otherwise>
														</xsl:choose>												
													</FLASH_POINT_UNIT>
													<IMDG_CODE_PAGE>
														<xsl:value-of select="ImoImdgClass"/>
													</IMDG_CODE_PAGE>
													<IMO_CLASS>
														<xsl:value-of select="ImoImdgClass"/>
													</IMO_CLASS>
													<PACKING_GROUP>
														<xsl:value-of select="ImoPackingGroup"/>
													</PACKING_GROUP>
													<PROPER_SHIPPING_NAME>
														<xsl:value-of select="ImoProperShippingName"/>
													</PROPER_SHIPPING_NAME>
													<UNDG_CODE>
														<xsl:value-of select="ImoUnNumber"/>
													</UNDG_CODE>
													<SUBSIDIARY_HAZARD>
														<xsl:value-of select="ImoLabel1"/>
													</SUBSIDIARY_HAZARD>
													<NUMBER_OF_PACKAGES>
														<xsl:value-of select="../../GoodNumberOfPieces"/>
													</NUMBER_OF_PACKAGES>
													<PACKAGE_CODE>
														<xsl:value-of select="../../GoodNumberOfPieces/@Unit"/>
													</PACKAGE_CODE>
													<GROSS_WEIGHT>
														<xsl:value-of select="replace(format-number(number(../../GoodGrossWeight), '#.000'), 'NaN', '')"/>
													</GROSS_WEIGHT>												
													<NET_WEIGHT>
														<xsl:value-of select="replace(format-number(number(../../GoodNettWeight), '#.000'), 'NaN', '')"/>
													</NET_WEIGHT>
													<GROSS_WEIGHT_UNIT>KG</GROSS_WEIGHT_UNIT>
													<NET_WEIGHT_UNIT>KG</NET_WEIGHT_UNIT>
													<!--ImoRemarks/Remark/RemarkDetails/Detail/DetailLineNumber & DetailInstruction-->
													<!--ImoFreeRemarks/Remark/RemarkDetails/Detail/DetailLineNumber & DetailInstruction-->
													<!--ImoTremCard-->
												</FMSDOM_DANGEROUS_GOOD>
											</xsl:for-each>
										</FMSDOM_DANGEROUS_GOODS>
									</xsl:if>
									<FMSDOM_GOOD_ITEMS>
										<FMSDOM_GOOD_ITEM ACTION="CREATE_UPDATE" SEARCH_FIELDS="ITEM_IDENTIFIER">
											<xsl:attribute name="KEY" select="concat($BL, 'FGO-IT-', $filePosition, '-', $goodGroup, '-', $goodPosition, '-', position())"/>
											<xsl:attribute name="PARENT_KEY" select="concat($BL, 'FGO-', $filePosition, '-', $goodGroup, '-', $goodPosition, '-', position())"/>
											
											<GROSS_WEIGHT>
												<xsl:value-of select="replace(format-number(number(GoodGrossWeight), '#.000'), 'NaN', '')"/>
											</GROSS_WEIGHT>
											<NET_WEIGHT>
												<xsl:value-of select="replace(format-number(number(GoodNettWeight), '#.000'), 'NaN', '')"/>
											</NET_WEIGHT>
											<VOLUME>
												<xsl:value-of select="replace(format-number(number(GoodVolume), '#.000'), 'NaN', '')"/>
											</VOLUME>
											<VOLUME_WEIGHT>
												<xsl:choose>
													<xsl:when test="number(GoodGrossWeight) div 1000 gt number(GoodVolume)">
														<xsl:value-of select="replace(format-number(number(GoodGrossWeight) div 1000, '#.000'), 'NaN', '')"/>
													</xsl:when>
													<xsl:otherwise>
														<xsl:value-of select="replace(format-number(number(GoodVolume), '#.000'), 'NaN', '')"/>
													</xsl:otherwise>
												</xsl:choose>
											</VOLUME_WEIGHT>
											<VOLUME_WEIGHT_UNIT>MT</VOLUME_WEIGHT_UNIT>									
											<GROSS_WEIGHT_UNIT>KG</GROSS_WEIGHT_UNIT>
											<NET_WEIGHT_UNIT>KG</NET_WEIGHT_UNIT>
											<VOLUME_UNIT>CBM</VOLUME_UNIT>
											<NUMBER_OF_ITEMS>										
												<xsl:choose>
													<!--test goodswitch-->
													<xsl:when test="(contains('PE,GT,SV', normalize-space(upper-case(../../FileReserveFields/ReserveField4))) or $FCLorLCL = 'LCL' or ($MBLorRBL = 'MBL' or $MBLorRBL = 'RBLasMBL')) and number(replace(string(number(GoodUdf/Udf[UdfCode = 'GIDnrPackages1']/UdfValue)), 'NaN', '0')) gt 0">
														<xsl:value-of select="GoodUdf/Udf[UdfCode = 'GIDnrPackages1']/UdfValue"/>
													</xsl:when>
													<xsl:when test="string-length(normalize-space(GoodNumberOfPieces)) le 0">
														<xsl:text>1</xsl:text>
													</xsl:when>
													<xsl:otherwise>
														<xsl:value-of select="GoodNumberOfPieces"/>
													</xsl:otherwise>
												</xsl:choose>								
											</NUMBER_OF_ITEMS>
											<PACKAGE_CODE>
												<xsl:choose>
													<!--Test Goodswitch-->
													<xsl:when test="(contains('PE,GT,SV', normalize-space(upper-case(../../FileReserveFields/ReserveField4))) or $FCLorLCL = 'LCL' or ($MBLorRBL = 'MBL' or $MBLorRBL = 'RBLasMBL')) and number(replace(string(number(GoodUdf/Udf[UdfCode = 'GIDnrPackages1']/UdfValue)), 'NaN', '0')) gt 0">
														<xsl:value-of select="GoodUdf/Udf[UdfCode = 'Packing1']/UdfValue"/>
													</xsl:when>
													<xsl:when test="string-length(normalize-space(GoodNumberOfPieces/@Unit)) le 0">
														<xsl:text>BULK</xsl:text>
													</xsl:when>
													<xsl:otherwise>
														<xsl:value-of select="GoodNumberOfPieces/@Unit"/>
													</xsl:otherwise>
												</xsl:choose>
											</PACKAGE_CODE>
											<ITEM_IDENTIFIER>
												<xsl:value-of select="GoodCustomerReference"/>
											</ITEM_IDENTIFIER>
											<FMSDOM_GOOD_ITEM_GIETS>										
												<FMSDOM_GOOD_ITEM_GIET>
													<xsl:attribute name="RELATION_IDENTIFIER">
														<xsl:value-of select="concat($BL, 'FCO-GO-IT-', ID)"/>
													</xsl:attribute>
												</FMSDOM_GOOD_ITEM_GIET>
												<xsl:choose>
													<xsl:when test="../../FileContainers/Container">
														<xsl:if test="	(number($filePosition) gt 1 and string-length(normalize-space($MBLorRBL)) gt 0) or
																		(number($filePosition) le 1 and string-length(normalize-space($MBLorRBL)) le 0)">
															<xsl:if test="string-length(normalize-space($BL)) le 0">
																<FMSDOM_GOOD_ITEM_GIET>
																	<xsl:attribute name="RELATION_IDENTIFIER">
																		<xsl:value-of select="concat($BL, 'FCO-GO-IT-PRE-', ID)"/>
																	</xsl:attribute>
																</FMSDOM_GOOD_ITEM_GIET>
															</xsl:if>
														</xsl:if>
													</xsl:when>
													<xsl:otherwise>
														<xsl:if test="(number($filePosition) gt 1 and $MBLorRBL != 'RBL') or
																	  (number($filePosition) le 1 and $MBLorRBL != 'RBL')">
															<xsl:if test="string-length(normalize-space($BL)) le 0">
																<FMSDOM_GOOD_ITEM_GIET>
																	<xsl:attribute name="RELATION_IDENTIFIER">
																		<xsl:value-of select="concat($BL, 'FCO-GO-IT-PRE-', ID)"/>
																	</xsl:attribute>
																</FMSDOM_GOOD_ITEM_GIET>
															</xsl:if>
														</xsl:if>
													</xsl:otherwise>
												</xsl:choose>
												<FMSDOM_GOOD_ITEM_GIET>
													<xsl:attribute name="RELATION_IDENTIFIER">
														<xsl:value-of select="concat($BL, 'FCO-GO-IT-MAIN-', ID)"/>
													</xsl:attribute>
												</FMSDOM_GOOD_ITEM_GIET>
												<xsl:if test="string-length(normalize-space($BL)) le 0 and
																(contains($FileTermsOfDelivery, 'CIP') or contains($FileTermsOfDelivery, 'CPT') or 
																 contains($FileTermsOfDelivery, 'DDP') or contains($FileTermsOfDelivery, 'DAP') or 
																 contains($FileTermsOfDelivery, 'DPU'))">
													<FMSDOM_GOOD_ITEM_GIET>
														<xsl:attribute name="RELATION_IDENTIFIER">
															<xsl:value-of select="concat($BL, 'FCO-GO-IT-ON-', ID)"/>
														</xsl:attribute>
													</FMSDOM_GOOD_ITEM_GIET>
												</xsl:if>
											</FMSDOM_GOOD_ITEM_GIETS>
										</FMSDOM_GOOD_ITEM>
									</FMSDOM_GOOD_ITEMS>
									<FMSDOM_GOOD_GIETS>															
										<FMSDOM_GOOD_GIET>
											<xsl:attribute name="RELATION_IDENTIFIER">
												<xsl:value-of select="concat($BL, 'FCO-GO-IT-', ID)"/>
											</xsl:attribute>
										</FMSDOM_GOOD_GIET>
										<xsl:choose>
											<xsl:when test="../../FileContainers/Container">
												<xsl:if test="	(number($filePosition) gt 1 and string-length(normalize-space($MBLorRBL)) gt 0) or
																(number($filePosition) le 1 and string-length(normalize-space($MBLorRBL)) le 0)">
													<xsl:if test="string-length(normalize-space($BL)) le 0">
														<FMSDOM_GOOD_GIET>
															<xsl:attribute name="RELATION_IDENTIFIER">
																<xsl:value-of select="concat($BL, 'FCO-GO-IT-PRE-', ID)"/>
															</xsl:attribute>
														</FMSDOM_GOOD_GIET>
													</xsl:if>
												</xsl:if>
											</xsl:when>
											<xsl:otherwise>
												<xsl:if test="(number($filePosition) gt 1 and $MBLorRBL != 'RBL') or
															  (number($filePosition) le 1 and $MBLorRBL != 'RBL')">
													<xsl:if test="string-length(normalize-space($BL)) le 0">
														<FMSDOM_GOOD_GIET>
															<xsl:attribute name="RELATION_IDENTIFIER">
																<xsl:value-of select="concat($BL, 'FCO-GO-IT-PRE-', ID)"/>
															</xsl:attribute>
														</FMSDOM_GOOD_GIET>
													</xsl:if>
												</xsl:if>
											</xsl:otherwise>
										</xsl:choose>
										<FMSDOM_GOOD_GIET>
											<xsl:attribute name="RELATION_IDENTIFIER">
												<xsl:value-of select="concat($BL, 'FCO-GO-IT-MAIN-', ID)"/>
											</xsl:attribute>
										</FMSDOM_GOOD_GIET>
										<xsl:if test="string-length(normalize-space($BL)) le 0 and
														(contains($FileTermsOfDelivery, 'CIP') or contains($FileTermsOfDelivery, 'CPT') or 
														 contains($FileTermsOfDelivery, 'DDP') or contains($FileTermsOfDelivery, 'DAP') or 
														 contains($FileTermsOfDelivery, 'DPU'))">
											<FMSDOM_GOOD_GIET>
												<xsl:attribute name="RELATION_IDENTIFIER">
													<xsl:value-of select="concat($BL, 'FCO-GO-IT-ON-', ID)"/>
												</xsl:attribute>
											</FMSDOM_GOOD_GIET>	
										</xsl:if>								
									</FMSDOM_GOOD_GIETS>
								</FMSDOM_GOOD>
							</xsl:for-each>
						</xsl:for-each-group>					
					</FMSDOM_GOODS>
				</xsl:if>
				<xsl:if test="string-length(normalize-space($BL)) gt 0">
					<FMS_BL SEARCH_FIELDS="EXPORT_REFERENCE" ACTION="CREATE_UPDATE">
						<xsl:attribute name="KEY" select="concat('BLFMS_BL-', $filePosition)"/>
						<CARRIER_BOOKING_NBR>
							<xsl:value-of select="FileAgentReference"/>
						</CARRIER_BOOKING_NBR>
						<FORWARDER_REFERENCE_NBR/>
						<SHIPPER_REFERENCE_NBR>
							<xsl:value-of select="FileCustomerReference"/>
						</SHIPPER_REFERENCE_NBR>
						<SERVICE_TYPE>
							<xsl:choose>
								<xsl:when test="contains($FileTermsOfDelivery, 'CIP') or contains($FileTermsOfDelivery, 'CPT') or contains($FileTermsOfDelivery, 'DDP') 
											 or contains($FileTermsOfDelivery, 'DAP') or contains($FileTermsOfDelivery, 'DPU')">
									<xsl:text>29</xsl:text>
								</xsl:when>
								<xsl:otherwise>
									<xsl:value-of select="FileUdf/Udf[UdfCode = 'ContrCarriage-code']/UdfValue"/>
								</xsl:otherwise>
							</xsl:choose>							
						</SERVICE_TYPE>
						<EXPORT_REFERENCE>
							<xsl:value-of select="FileCustomerReference"/>
						</EXPORT_REFERENCE>
						<xsl:variable name="udfBLParties" select="string-join(FileParties/Party[@Type = 'BL']/PartyUdf/Udf[UdfCode != 'PANAME']/UdfValue, '')"/>
						<xsl:choose>							
							<xsl:when test="contains($udfBLParties, 'AA') and $company_code != 'FPLES' and $company_code != 'FRACHTITA'">
								<xsl:variable name="panameBLParties" select="upper-case(string-join(FileParties/Party[@Type = 'BL']/PartyUdf/Udf[UdfCode = 'PANAME']/UdfValue, ''))"/>
								<xsl:choose>
									<xsl:when test="contains($panameBLParties, 'DUBAI') or contains($panameBLParties, 'FZE')">
										<PLACE_OF_ISSUE_COUNTRY>
											<xsl:text>AE</xsl:text>
										</PLACE_OF_ISSUE_COUNTRY>
										<PLACE_OF_ISSUE_LOCODE>
											<xsl:text>DXB</xsl:text>
										</PLACE_OF_ISSUE_LOCODE>
									</xsl:when>
									<xsl:when test="contains($panameBLParties, 'SINGAPORE')">
										<PLACE_OF_ISSUE_COUNTRY>
											<xsl:text>SG</xsl:text>
										</PLACE_OF_ISSUE_COUNTRY>
										<PLACE_OF_ISSUE_LOCODE>
											<xsl:text>SIN</xsl:text>
										</PLACE_OF_ISSUE_LOCODE>
									</xsl:when>
									<xsl:when test="contains($panameBLParties, 'ISTANBUL')">
										<PLACE_OF_ISSUE_COUNTRY>
											<xsl:text>TR</xsl:text>
										</PLACE_OF_ISSUE_COUNTRY>
										<PLACE_OF_ISSUE_LOCODE>
											<xsl:text>IST</xsl:text>
										</PLACE_OF_ISSUE_LOCODE>
									</xsl:when>
									<xsl:when test="contains($panameBLParties, 'MALAYSIA')">
										<PLACE_OF_ISSUE_COUNTRY>
											<xsl:text>MY</xsl:text>
										</PLACE_OF_ISSUE_COUNTRY>
										<PLACE_OF_ISSUE_LOCODE>
											<xsl:text>KUL</xsl:text>
										</PLACE_OF_ISSUE_LOCODE>
									</xsl:when>
									<xsl:otherwise>
										<PLACE_OF_ISSUE_COUNTRY>
											<xsl:value-of select="substring(FilePortOfDischarge, 1, 2)"/>
										</PLACE_OF_ISSUE_COUNTRY>
										<PLACE_OF_ISSUE_LOCODE>
											<xsl:value-of select="substring(FilePortOfDischarge, 3)"/>
										</PLACE_OF_ISSUE_LOCODE>
									</xsl:otherwise>
								</xsl:choose>
							</xsl:when>
							<xsl:otherwise>
								<PLACE_OF_ISSUE_COUNTRY>
									<xsl:value-of select="$fmsSLACode"/>
								</PLACE_OF_ISSUE_COUNTRY>
								<PLACE_OF_ISSUE_LOCODE>
									<xsl:value-of select="$fmsSLACode"/>
								</PLACE_OF_ISSUE_LOCODE>
							</xsl:otherwise>
						</xsl:choose>
						<DATE_OF_ISSUE>
							<xsl:value-of select="concat(tokenize(FileEtd, '/')[last()], '-', tokenize(FileEtd, '/')[2], '-', tokenize(FileEtd, '/')[1])"/>
						</DATE_OF_ISSUE>
						<xsl:for-each select="//FileGoodLines[1]/GoodLine[1]/GoodBillsOfLading[1]/BillOfLading[1]">
							<LETTER_OF_CREDIT>
								<xsl:value-of select="BlUdf/Udf[UdfCode = 'LETTEROFCR']/UdfValue"/>
							</LETTER_OF_CREDIT>
							<DOCUMENT_TYPE>
								<xsl:value-of select="BlType"/>
							</DOCUMENT_TYPE>
							<xsl:variable name="SLACodeFMS">
								<xsl:choose>	
									<xsl:when test="string-length(normalize-space(../../../../FileScenario)) > 0">
										<xsl:choose>
											<xsl:when test="upper-case(normalize-space(../../../../FileStatus)) = 'TP'">
												<xsl:value-of select="concat(../../../../FileStatus, ../../../../FileScenario)"/>
											</xsl:when>
											<xsl:otherwise>
												<xsl:value-of select="../../../../FileScenario"/>
											</xsl:otherwise>
										</xsl:choose>
									</xsl:when>
									<xsl:otherwise>
										<xsl:value-of select="$defaultScenario"/>
										<!--Prograse Basexml Conversions & Defaults-->
									</xsl:otherwise>
								</xsl:choose>
							</xsl:variable>
							<MOVE_TYPE>
								<xsl:value-of select="$SLACodeFMS"/>
							</MOVE_TYPE>
							<FREIGHT_PAYABLE_AT_COUNTRY>
								<xsl:value-of select="$SLACodeFMS"/>
							</FREIGHT_PAYABLE_AT_COUNTRY>
							<FREIGHT_PAYABLE_AT_LOCODE>
								<xsl:value-of select="$SLACodeFMS"/>
							</FREIGHT_PAYABLE_AT_LOCODE>
							<NUMBER_OF_COPIES>
								<xsl:value-of select="BlType"/>
							</NUMBER_OF_COPIES>
							<NUMBER_OF_ORIGINALS>
								<xsl:value-of select="BlType"/>
							</NUMBER_OF_ORIGINALS>
							<!--BlOnCarriage-->
							<!--BlVesselName-->
							<!--BlShipper-->
							<!--BlNotify-->
							<!--BlUdf-->
							<FMS_BL_GIETS>
								<xsl:for-each select="//GoodLine">
									<FMS_BL_GIET>
										<xsl:attribute name="RELATION_IDENTIFIER">
											<xsl:value-of select="concat($BL, 'FCO-GO-IT-MAIN-', ID)"/>
										</xsl:attribute>
									</FMS_BL_GIET>
								</xsl:for-each>
							</FMS_BL_GIETS>
						</xsl:for-each>
					</FMS_BL>
				</xsl:if>
				<xsl:if test="FileContainers/Container">
					<xsl:if test="	(number($filePosition) le 1 and string-length(normalize-space($MBLorRBL)) gt 0) or 
									(number($filePosition) le 1 and string-length(normalize-space($MBLorRBL)) le 0) or 
									(number($filePosition) gt 1 and string-length(normalize-space($MBLorRBL)) gt 0 and string-length(normalize-space($BL)) gt 0)">
						<FMSDOM_EQUIPMENTS>
							<xsl:if test="$SERVICE_CODE != 'ERST_CR' and string-length(normalize-space($MBLorRBL)) le 0">
								<xsl:attribute name="ACTION">
									<xsl:text>DELETE_NOT_CU</xsl:text>
								</xsl:attribute>
							</xsl:if>
							<xsl:for-each-group select="FileContainers/Container" group-by="ContContainerNumber">
								<xsl:variable name="ID">
									<xsl:choose>
										<xsl:when test="string-length(normalize-space(ID)) gt 0">
											<xsl:value-of select="ID"/>
										</xsl:when>
										<xsl:otherwise>
											<xsl:variable name="containerNumber" select="ContContainerNumber"/>
											<xsl:value-of select="//Container[ContContainerNumber = $containerNumber and string-length(normalize-space(ID)) gt 0][1]/ID"/>
										</xsl:otherwise>
									</xsl:choose>
								</xsl:variable>
								<xsl:if test="string-length(normalize-space($ID)) gt 0">
									<FMSDOM_EQUIPMENT SEARCH_FIELDS="EQUIPMENT_IDENTIFIER,TECHNICAL_REFERENCE" ACTION="CREATE_UPDATE">
										
										
										<xsl:attribute name="KEY" select="concat($BL, 'FCO-', $filePosition, '-', $ID)"/>
										
										<xsl:variable name="RFF-LI">
											<xsl:choose>
												<xsl:when test="$MBLorRBL = 'MBL' or $MBLorRBL = 'RBLasMBL'">
													<xsl:variable name="containerNumber" select="ContContainerNumber"/>
													<xsl:variable name="EQDplusRFF-LI">
														<xsl:for-each select="tokenize($allEQD, '-')">
															<xsl:variable name="EQDPosition" select="position()"/>
															<EQD>
																<xsl:attribute name="RFF-LI" select="tokenize($allRFF-LI, '-')[$EQDPosition]"/>
																<xsl:value-of select="."/>
															</EQD>
														</xsl:for-each>
													</xsl:variable>
													<xsl:variable name="RFF-LILinkedToCurrentEQD" select="string-join($EQDplusRFF-LI/EQD[. = $containerNumber]/@RFF-LI, '-')"/>
													<xsl:for-each select="tokenize($RFF-LILinkedToCurrentEQD, '-')">
														<xsl:sort select="."/>
														<RFF-LI>
															<xsl:value-of select="."/>
														</RFF-LI>
													</xsl:for-each>
												</xsl:when>
												<xsl:when test="count(../../FileGoodLines/GoodLine) le 0">
													<!--we are at mainfile in the progress basexml -> going to subfiles for RFF-LI-->
													<xsl:for-each select="../../SubFiles/MainFile/FileGoodLines/GoodLine[Containers/Container/ContainerID = $ID]">
														<xsl:sort select="GoodCustomerReference"/>
														<RFF-LI>
															<xsl:value-of select="normalize-space(tokenize(GoodCustomerReference, '-')[1])"/>
														</RFF-LI>
													</xsl:for-each>
												</xsl:when>
												<xsl:otherwise>
													<xsl:for-each select="../../FileGoodLines/GoodLine[Containers/Container/ContainerID = $ID]">
														<xsl:sort select="GoodCustomerReference"/>
														<RFF-LI>
															<xsl:value-of select="normalize-space(tokenize(GoodCustomerReference, '-')[1])"/>
														</RFF-LI>
													</xsl:for-each>
												</xsl:otherwise>
											</xsl:choose>
										</xsl:variable>
										
										<xsl:variable name="technicalRef" select="substring(string-join(distinct-values($RFF-LI/RFF-LI), '-'), 1, 98)"/>
										<xsl:if test="string-length(normalize-space($technicalRef)) gt 0">
											<TECHNICAL_REFERENCE>																
												<xsl:value-of select="$technicalRef"/>
											</TECHNICAL_REFERENCE>
										</xsl:if>
										<xsl:if test="string-length(normalize-space(../../FileAgentReference)) gt 0">
											<TYPE_OF_REF>BN</TYPE_OF_REF>
											<REFERENCE>
												<xsl:value-of select="../../FileAgentReference"/>
											</REFERENCE>
										</xsl:if>
										<EQUIPMENT_VARIATION>
											<xsl:text>CO</xsl:text>
										</EQUIPMENT_VARIATION>
										<EQUIPMENT_IDENTIFIER>
											<xsl:value-of select="ContContainerNumber"/>
										</EQUIPMENT_IDENTIFIER>
										<EQUIPMENT_SIZE>
											<xsl:value-of select="ContSizeOfContainer[1]"/>
										</EQUIPMENT_SIZE>
										<EQUIPMENT_TYPE>
											<xsl:value-of select="ContTypeOfContainer"/>
										</EQUIPMENT_TYPE>
										<NET_WEIGHT>
											<xsl:value-of select="replace(format-number(number(ContNettWeight), '#.000'), 'NaN', '')"/>
										</NET_WEIGHT>
										<GROSS_WEIGHT>
											<xsl:value-of select="replace(format-number(number(ContGrossWeight), '#.000'), 'NaN', '')"/>
										</GROSS_WEIGHT>
										<SEAL1>
											<xsl:value-of select="ContSeal1"/>
										</SEAL1>
										<SEAL2>
											<xsl:value-of select="ContSeal2"/>
										</SEAL2>
										<xsl:if test="string-length(normalize-space(ContainerUdf/Udf[upper-case(UdfCode) = 'SOLAS_VW']/UdfValue)) gt 0">
											<TYPE_OF_WEIGHT>
												<xsl:text>VGM</xsl:text>
											</TYPE_OF_WEIGHT>
											<VERIFIED_WEIGHT>
												<xsl:value-of select="ContainerUdf/Udf[upper-case(UdfCode) = 'SOLAS_VW']/UdfValue"/>
											</VERIFIED_WEIGHT>
										</xsl:if>
										<xsl:if test="count(ContainerUdf/Udf[UdfCode != 'SOLAS_VW' and UdfCode != 'STAT_CONT' and UdfCode != 'SOLAS_TX' and UdfCode != 'SOLAS_MCA']) gt 0">
											<GEN_UDF_INSTANCES>
												<xsl:for-each-group select="ContainerUdf/Udf[UdfCode != 'SOLAS_VW' and UdfCode != 'STAT_CONT' and UdfCode != 'SOLAS_TX' and UdfCode != 'SOLAS_MCA']" group-by="UdfCode">
													<GEN_UDF_INSTANCE SEARCH_FIELDS="UDF_CODE" ACTION="CREATE_UPDATE">
														<xsl:attribute name="KEY" select="concat($BL, 'CUDF-', $filePosition, '-', $ID, '-', position())"/>
														<xsl:for-each select="current-group()[last()]">
															<UDF_CODE>
																<xsl:if test="UdfCode = 'FTX-AAF'">
																	<xsl:text>CO_</xsl:text>
																</xsl:if>
																<xsl:value-of select="UdfCode"/>
															</UDF_CODE>
															<UDF_VALUE>
																<xsl:value-of select="normalize-space(substring(UdfValue, 1, 500))"/>
															</UDF_VALUE>
														</xsl:for-each>
													</GEN_UDF_INSTANCE>
												</xsl:for-each-group>
											</GEN_UDF_INSTANCES>
										</xsl:if>
										<FMSDOM_EQUIPMENT_GIETS>									
											<xsl:for-each select="//FileGoodLines/GoodLine[Containers/Container/ContainerID = $ID]">
												<FMSDOM_EQUIPMENT_GIET>
													<xsl:attribute name="RELATION_IDENTIFIER">
														<xsl:value-of select="concat($BL, 'FCO-GO-IT-', ID)"/>
													</xsl:attribute>										
												</FMSDOM_EQUIPMENT_GIET>
												<xsl:if test="	(number($filePosition) le 1 and string-length(normalize-space($MBLorRBL)) gt 0) or 
																(number($filePosition) le 1 and string-length(normalize-space($MBLorRBL)) le 0)">
													<xsl:if test="string-length(normalize-space($BL)) le 0">
														<FMSDOM_EQUIPMENT_GIET>
															<xsl:attribute name="RELATION_IDENTIFIER">
																<xsl:value-of select="concat($BL, 'FCO-GO-IT-PRE-', ID)"/>
															</xsl:attribute>										
														</FMSDOM_EQUIPMENT_GIET>
													</xsl:if>
												</xsl:if>
												<FMSDOM_EQUIPMENT_GIET>
													<xsl:attribute name="RELATION_IDENTIFIER">
														<xsl:value-of select="concat($BL, 'FCO-GO-IT-MAIN-', ID)"/>
													</xsl:attribute>										
												</FMSDOM_EQUIPMENT_GIET>
												<xsl:if test="string-length(normalize-space($BL)) le 0 and number($filePosition) le 1 and
															(contains($FileTermsOfDelivery, 'CIP') or contains($FileTermsOfDelivery, 'CPT') or 
															 contains($FileTermsOfDelivery, 'DDP') or contains($FileTermsOfDelivery, 'DAP') or 
															 contains($FileTermsOfDelivery, 'DPU'))">
													<FMSDOM_EQUIPMENT_GIET>
														<xsl:attribute name="RELATION_IDENTIFIER">
															<xsl:value-of select="concat($BL, 'FCO-GO-IT-ON-', ID)"/>
														</xsl:attribute>										
													</FMSDOM_EQUIPMENT_GIET>
												</xsl:if>
											</xsl:for-each>
										</FMSDOM_EQUIPMENT_GIETS>
									</FMSDOM_EQUIPMENT>
								</xsl:if>
							</xsl:for-each-group>
						</FMSDOM_EQUIPMENTS>
					</xsl:if>
				</xsl:if>
			</xsl:if>
		</FMSWFM_ORDER>
	</xsl:template>
</xsl:stylesheet>
