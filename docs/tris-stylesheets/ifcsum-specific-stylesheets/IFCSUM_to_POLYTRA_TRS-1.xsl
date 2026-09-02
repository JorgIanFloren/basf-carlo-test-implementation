<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

	<xsl:output method="xml" indent="yes" encoding="UTF-8" standalone="yes" omit-xml-declaration="no"/>
	
	<!--IFCSUM-->
	<xsl:param name="MessageFunctionCode"/>
	<xsl:param name="TRS-1_Company"/>
	<xsl:param name="Group"/>

	<xsl:param name="EdifactSenderId"/>
	<xsl:param name="EdifactReceiverId"/>

<xsl:template match="/">
	<TRS_DATA>
		<ORDERS>
			<xsl:for-each select="//Group0">
				<!-- if no RFF-SI then LCL else FCL -->
				<xsl:variable name="RFF-SI" select="Segment_group_9/Segment_group_16/Reference/REFERENCE/Reference_identifier"/>
				
				<xsl:variable name="Group0" select="."/>
			
				<xsl:choose>
					<xsl:when test="string-length(normalize-space($RFF-SI)) le 0">
						<xsl:variable name="RFF-LI">
							<xsl:for-each select="$Group0/Segment_group_26/Segment_group_51/Segment_group_55/Reference/REFERENCE[Reference_code_qualifier = 'LI']">
								<xsl:sort select="Reference_identifier"/>
								<RFF-LI>
									<xsl:value-of select="normalize-space(Reference_identifier)"/>
								</RFF-LI>
							</xsl:for-each>
						</xsl:variable>
						
						<xsl:for-each select="$RFF-LI/RFF-LI">
							<xsl:call-template name="ORDER">
								<xsl:with-param name="Group0" select="$Group0"/>
								<xsl:with-param name="BL" select="''"/>
								<xsl:with-param name="RFF-SI" select="$RFF-SI"/>
								<xsl:with-param name="RFF-LI" select="."/>
							</xsl:call-template>
						</xsl:for-each>
					</xsl:when>
					<xsl:otherwise>
						<xsl:call-template name="ORDER">
							<xsl:with-param name="Group0" select="$Group0"/>
							<xsl:with-param name="BL" select="''"/>
							<xsl:with-param name="RFF-SI" select="$RFF-SI"/>
						</xsl:call-template>
						<!--Create BL-ORDER when MessageFunctionCode = create = 9-->
						<xsl:if test="$MessageFunctionCode = '9'">
							<xsl:call-template name="ORDER">
								<xsl:with-param name="Group0" select="$Group0"/>
								<xsl:with-param name="BL" select="'BL'"/>
								<xsl:with-param name="RFF-SI" select="$RFF-SI"/>
							</xsl:call-template>
						</xsl:if>
					</xsl:otherwise>
				</xsl:choose>
			</xsl:for-each>
		</ORDERS>
	</TRS_DATA>
</xsl:template>

<xsl:template name="ORDER">
	<xsl:param name="Group0"/>
	<xsl:param name="BL"/>
	<xsl:param name="RFF-SI"/>
	<xsl:param name="RFF-LI"/>
	
	<FMSWFM_ORDER ACTION="UPDATE" DATA_LEVEL="MS">
		<xsl:variable name="filePosition" select="position()"/>
		<xsl:choose>
			<xsl:when test="string-length(normalize-space($RFF-SI)) le 0">
				<xsl:attribute name="SEARCH_FIELDS">
					<xsl:text>PI_STATUS,COMPANY_CODE,GROUP_CODE,PI_CATEGORY</xsl:text>
				</xsl:attribute>
				<xsl:attribute name="TEXT_SEARCH" select="concat($RFF-LI, ' within technical_reference')"/>
			</xsl:when>
			<xsl:otherwise>
				<xsl:attribute name="SEARCH_FIELDS">
					<xsl:text>PI_STATUS,CUSTOMER_REFERENCE,COMPANY_CODE,GROUP_CODE,PI_CATEGORY</xsl:text>
				</xsl:attribute>
			</xsl:otherwise>
		</xsl:choose>
		<xsl:attribute name="KEY" select="concat($BL, 'FMS-', $filePosition)"/>
		<xsl:variable name="SERVICE_CODE">
			<xsl:choose>
				<xsl:when test="$MessageFunctionCode = '9'">
					<xsl:text>IFCSUM_CR</xsl:text>	
				</xsl:when>
				<xsl:when test="$MessageFunctionCode = '4'">
					<xsl:text>IFCSUM_UP</xsl:text>	
				</xsl:when>
				<xsl:when test="$MessageFunctionCode = '1'">
					<xsl:text>IFCSUM_CA</xsl:text>	
				</xsl:when>
			</xsl:choose>
		</xsl:variable>
		<xsl:if test="string-length(normalize-space($BL)) le 0">
			<xsl:attribute name="SERVICE_CODE" select="$SERVICE_CODE"/>
		</xsl:if>
		<xsl:if test="string-length(normalize-space($BL)) gt 0">
			<xsl:attribute name="PARENT_KEY" select="concat('FMS-', $filePosition)"/>
		</xsl:if>
		
		<xsl:if test="string-length(normalize-space($RFF-SI)) gt 0">
			<CUSTOMER_REFERENCE>
				<xsl:value-of select="concat($RFF-SI, 'BL00')"/>
			</CUSTOMER_REFERENCE>
		</xsl:if>
		<PI_STATUS>OP</PI_STATUS>
		<COMPANY_CODE>
			<xsl:value-of select="$TRS-1_Company"/>
		</COMPANY_CODE>					
		<GROUP_CODE>
			<xsl:value-of select="$Group"/>
		</GROUP_CODE>
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

		<GEN_UDF_INSTANCES>
			<GEN_UDF_INSTANCE SEARCH_FIELDS="UDF_CODE" ACTION="CREATE_UPDATE" KEY="{concat($BL, 'REC-', $filePosition)}">
				<UDF_CODE>BASF_REC</UDF_CODE>
				<UDF_VALUE><xsl:value-of select="$EdifactSenderId"/></UDF_VALUE>
			</GEN_UDF_INSTANCE>
		</GEN_UDF_INSTANCES>

		<xsl:variable name="unloadingDate" select="$Group0/Segment_group_9/Date_time_period/DATE_TIME_PERIOD[Date_or_time_or_period_format_code = '102' and Date_or_time_or_period_function_code_qualifier = '181']/Date_or_time_or_period_text"/>
		<xsl:variable name="unloadingTime" select="$Group0/Segment_group_9/Date_time_period/DATE_TIME_PERIOD[Date_or_time_or_period_format_code = '402' and Date_or_time_or_period_function_code_qualifier = '181']/Date_or_time_or_period_text"/>
		
		<xsl:if test="string-length(normalize-space($BL)) le 0">
			<WFM_PI_TASKS>
				<WFM_PI_TASK ACTION="CREATE">
					<xsl:attribute name="KEY" select="concat($BL, 'TASK2-', $filePosition)"/>
					<SLA_SERVICE_CODE>
						<xsl:value-of select="concat($SERVICE_CODE, '-T')"/>
					</SLA_SERVICE_CODE>
					<STATUS>DEX</STATUS>
				</WFM_PI_TASK>
				
				<xsl:if test="matches($unloadingDate, '^\d{8}$')">
					<WFM_PI_TASK ACTION="CREATE">
						<xsl:attribute name="KEY" select="concat($BL, 'TASK3-', $filePosition)"/>
						<SLA_SERVICE_CODE>IFCSUM-DTM-181</SLA_SERVICE_CODE>
						<STATUS>DEX</STATUS>
					</WFM_PI_TASK>
				</xsl:if>
			</WFM_PI_TASKS>
		</xsl:if>


		<xsl:if test="count($Group0/Segment_group_22/Name_and_address) gt 0 and string-length(normalize-space($RFF-SI)) gt 0">
			<FMSDOM_PARTIES>
				<xsl:for-each select="$Group0/Segment_group_22/Name_and_address">
					<FMSDOM_PARTY ACTION="CREATE_UPDATE" SEARCH_FIELDS="PARTY_QUALIFIER">
						<xsl:attribute name="KEY" select="concat($BL, 'FPA-', $filePosition, '-', position())"/>				
						<PARTY_QUALIFIER>
							<xsl:value-of select="Party_function_code_qualifier"/>
						</PARTY_QUALIFIER>							
						<VARIATION>
							<xsl:text>PA</xsl:text>
						</VARIATION>				
						<THIRDPARTY_NAME>
							<xsl:variable name="partyName" select="PARTY_NAME/Party_name_-_-1"/>
							<xsl:choose>
								<xsl:when test="string-length(normalize-space($partyName)) le 0">
									<xsl:text>TBN</xsl:text>
								</xsl:when>
								<xsl:otherwise>
									<xsl:value-of select="$partyName"/>
								</xsl:otherwise>
							</xsl:choose>							
						</THIRDPARTY_NAME>				
					</FMSDOM_PARTY>
				</xsl:for-each>
			</FMSDOM_PARTIES>
		</xsl:if>
		
		<xsl:if test="string-length(normalize-space($RFF-SI)) gt 0">
			<FMSDOM_EQUIPMENTS>						
				<xsl:for-each select="$Group0/Segment_group_22/Equipment_details[Equipment_type_code_qualifier = 'CN']">							
					<FMSDOM_EQUIPMENT ACTION="CREATE_UPDATE" SEARCH_FIELDS="TECHNICAL_REFERENCE">								
						<xsl:attribute name="KEY" select="concat($BL, 'FCO-', $filePosition, '-', position())"/>
						<TECHNICAL_REFERENCE>
							<xsl:variable name="ID" select="ID"/>
							<xsl:variable name="CO_RFF-LI">
								<xsl:for-each select="$Group0/Segment_group_26/Segment_group_51/Segment_group_55/Reference/REFERENCE[Reference_code_qualifier = 'LI']">
									<xsl:sort select="Reference_identifier"/>
									<RFF-LI>
										<xsl:value-of select="normalize-space(Reference_identifier)"/>
									</RFF-LI>
								</xsl:for-each>
							</xsl:variable>
							<xsl:value-of select="substring(string-join(distinct-values($CO_RFF-LI/RFF-LI), '-'), 1, 98)"/>
						</TECHNICAL_REFERENCE>
						<EQUIPMENT_VARIATION>
							<xsl:text>CO</xsl:text>
						</EQUIPMENT_VARIATION>
						<EQUIPMENT_IDENTIFIER>
							<xsl:value-of select="EQUIPMENT_IDENTIFICATION/Equipment_identifier"/>
						</EQUIPMENT_IDENTIFIER>
						<EQUIPMENT_SIZE>
							<xsl:value-of select="substring(EQUIPMENT_SIZE_AND_TYPE/Equipment_size_and_type_description_code, 1, 2)"/>
						</EQUIPMENT_SIZE>
						<EQUIPMENT_TYPE>
							<xsl:value-of select="substring(EQUIPMENT_SIZE_AND_TYPE/Equipment_size_and_type_description_code, 3, 2)"/>
						</EQUIPMENT_TYPE>
						<SEAL1>
							<xsl:value-of select="substring(../Seal_number[1]/Transport_unit_seal_identifier, 1, 15)"/>
						</SEAL1>
						<SEAL2>
							<xsl:value-of select="substring(../Seal_number[2]/Transport_unit_seal_identifier, 1, 15)"/>
						</SEAL2>
						<SEAL3>
							<xsl:value-of select="substring(../Seal_number[3]/Transport_unit_seal_identifier, 1, 15)"/>
						</SEAL3>
						
						<TYPE_OF_WEIGHT>
							<xsl:text>VGM</xsl:text>
						</TYPE_OF_WEIGHT>
						<VERIFIED_WEIGHT>
							<xsl:value-of select="../Measurements[Measurement_purpose_code_qualifier = 'WT' and MEASUREMENT_DETAILS/Measured_attribute_code = 'AAB']/VALUE_RANGE/Measure"/>
						</VERIFIED_WEIGHT>
					</FMSDOM_EQUIPMENT>						
				</xsl:for-each>
			</FMSDOM_EQUIPMENTS>
		</xsl:if>
		
		<FMSDOM_TRANSPORTS>
			<xsl:if test="string-length(normalize-space($BL)) le 0">
				<FMSDOM_TRANSPORT ACTION="UPDATE">
					<xsl:choose>
						<xsl:when test="string-length(normalize-space($RFF-SI)) le 0">
							<xsl:attribute name="SEARCH_FIELDS">
								<xsl:text>TRANSPORT_MODE</xsl:text>
							</xsl:attribute>
						</xsl:when>
						<xsl:otherwise>
							<xsl:attribute name="SEARCH_FIELDS">
								<xsl:text>TRANSPORT_MODE,REMARKS</xsl:text>
							</xsl:attribute>
						</xsl:otherwise>
					</xsl:choose>
					<xsl:attribute name="KEY" select="concat($BL, 'FTR-PRE-', $filePosition)"/>
					<TECHNICAL_REFERENCE>
						<xsl:value-of select="$Group0/Segment_group_1/Reference/REFERENCE[Reference_code_qualifier = 'AIW']/Reference_identifier"/>
					</TECHNICAL_REFERENCE>
					<TRANSPORT_MODE>PRE</TRANSPORT_MODE>
					<xsl:if test="string-length(normalize-space($RFF-SI)) gt 0">
						<REMARKS>
							<xsl:variable name="ID" select="ID"/>
							<xsl:variable name="TR_RFF-LI">
								<xsl:for-each select="$Group0/Segment_group_26/Segment_group_51/Segment_group_55/Reference/REFERENCE[Reference_code_qualifier = 'LI']">
									<xsl:sort select="Reference_identifier"/>
									<RFF-LI>
										<xsl:value-of select="normalize-space(tokenize(Reference_identifier, '-')[1])"/>
									</RFF-LI>
								</xsl:for-each>
							</xsl:variable>
							<xsl:value-of select="string-join(distinct-values($TR_RFF-LI/RFF-LI), '-')"/>
						</REMARKS>	
						
						<xsl:if test="matches($unloadingDate, '^\d{8}$')">
							<FMSDOM_TRANSPORT_STOPS>
								<FMSDOM_TRANSPORT_STOP SEARCH_FIELDS="HANDLING_TYPE" ACTION="CREATE_UPDATE">
									<xsl:attribute name="KEY" select="concat($BL, 'FTRS-PRE-', $filePosition)"/>
									<HANDLING_TYPE>LOAD</HANDLING_TYPE>
									<ACTUAL_TIME><!--20210127-->
										<xsl:variable name="unloadingTime2">
											<!--060000-->
											<xsl:choose>
												<xsl:when test="not(matches($unloadingTime, '^\d{6}$'))">
													<xsl:text>T00:00:00</xsl:text>
												</xsl:when>
												<xsl:otherwise>
													<xsl:value-of select="concat('T', substring($unloadingTime, 1, 2), ':', substring($unloadingTime, 3, 2), ':', substring($unloadingTime, 5, 2))"/>
												</xsl:otherwise>
											</xsl:choose>
										</xsl:variable>
										<xsl:value-of select="concat(substring($unloadingDate, 1, 4), '-', substring($unloadingDate, 5, 2), '-', substring($unloadingDate, 7, 2), $unloadingTime2)"/>
									</ACTUAL_TIME>
								</FMSDOM_TRANSPORT_STOP>
							</FMSDOM_TRANSPORT_STOPS>
						</xsl:if>
					</xsl:if>
				</FMSDOM_TRANSPORT>
			</xsl:if>
			<xsl:if test="string-length(normalize-space($RFF-SI)) gt 0">
				<FMSDOM_TRANSPORT ACTION="UPDATE" SEARCH_FIELDS="TRANSPORT_MODE">
					<xsl:attribute name="KEY" select="concat($BL, 'FTR-', $filePosition)"/>
					<TRANSPORT_MODE>MAIN</TRANSPORT_MODE>
					<TYPE>VESSEL</TYPE>
					<TYPEBEHAVIOUR>VESSEL</TYPEBEHAVIOUR>
					
					<xsl:if test="matches($unloadingDate, '^\d{8}$')">
						<FMSDOM_TRANSPORT_STOPS>
							<FMSDOM_TRANSPORT_STOP ACTION="UPDATE" SEARCH_FIELDS="PLACE_QUALIFIER">
								<xsl:attribute name="KEY" select="concat($BL, 'FTRS-1-1')"/>													
								<PLACE_QUALIFIER>9</PLACE_QUALIFIER>
								<HANDLING_TYPE>LOAD</HANDLING_TYPE>
								<START_TIME>
									<xsl:variable name="unloadingTime2">
										<!--060000-->
										<xsl:choose>
											<xsl:when test="not(matches($unloadingTime, '^\d{6}$'))">
												<xsl:text>T00:00:00</xsl:text>
											</xsl:when>
											<xsl:otherwise>
												<xsl:value-of select="concat('T', substring($unloadingTime, 1, 2), ':', substring($unloadingTime, 3, 2), ':', substring($unloadingTime, 5, 2))"/>
											</xsl:otherwise>
										</xsl:choose>
									</xsl:variable>
									<xsl:value-of select="concat(substring($unloadingDate, 1, 4), '-', substring($unloadingDate, 5, 2), '-', substring($unloadingDate, 7, 2), $unloadingTime2)"/>
								</START_TIME>								
							</FMSDOM_TRANSPORT_STOP>
						</FMSDOM_TRANSPORT_STOPS>
					</xsl:if>			
				</FMSDOM_TRANSPORT>
			</xsl:if>
		</FMSDOM_TRANSPORTS>
		
		<xsl:if test="string-length(normalize-space($BL)) le 0 and string-length(normalize-space($RFF-SI)) gt 0">
			<FMSDOM_GOODS>
				<xsl:for-each-group select="$Group0/Segment_group_26/Segment_group_51/Segment_group_55/Reference/REFERENCE[Reference_code_qualifier = 'LI']" group-by="concat(Reference_identifier, '-', Document_line_identifier)">
					<xsl:variable name="loopPosition" select="position()"/>
					<xsl:for-each select="current-group()">
						<FMSDOM_GOOD ACTION="UPDATE" SEARCH_FIELDS="TECHNICAL_REFERENCE">							
							<xsl:attribute name="KEY" select="concat($BL, 'FGO-', $filePosition, '-', $loopPosition, '-', position())"/>					
							
							<TECHNICAL_REFERENCE>
								<xsl:value-of select="concat(current-grouping-key(), '-', position())"/>
							</TECHNICAL_REFERENCE>
							<BOOKING_REFERENCE>
								<xsl:value-of select="current-grouping-key()"/>
							</BOOKING_REFERENCE>
							<GEN_UDF_INSTANCES>
								<GEN_UDF_INSTANCE SEARCH_FIELDS="UDF_CODE" ACTION="CREATE_UPDATE">
									<xsl:attribute name="KEY" select="concat($BL, 'FGUDF-', $filePosition, '-', $loopPosition, '-', position(), '-1')"/>														
									<UDF_CODE>
										<xsl:text>GO_MRN</xsl:text>
									</UDF_CODE>
									<UDF_VALUE>
										<xsl:value-of select="../../../../Segment_group_33/Reference/REFERENCE[Reference_code_qualifier = 'ABT']/Reference_identifier"/>
									</UDF_VALUE>
								</GEN_UDF_INSTANCE>
							</GEN_UDF_INSTANCES>
						</FMSDOM_GOOD>
					</xsl:for-each>
				</xsl:for-each-group>
			</FMSDOM_GOODS>
		</xsl:if>
	</FMSWFM_ORDER>
</xsl:template>

</xsl:stylesheet>