<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

	<xsl:output encoding="UTF-8" indent="yes" method="xml"/>
	
	<xsl:param name="MessageKey"/>
	<xsl:param name="MessageSenderID"/>
	<xsl:param name="MessageTaskCode"/>
	
	<xsl:param name="S3-00010"/>
	<xsl:param name="S3-00014"/>
	
	<xsl:template match="/">
		<xsl:for-each select="//TRS_DATA/ORDERS/FMSWFM_ORDER">
			<EDIDOC>
				<xsl:variable name="date">
					<xsl:value-of select="tokenize(string(current-date()), '\+')[1]"/>
				</xsl:variable>
				<xsl:variable name="time">
					<xsl:value-of select="current-time()"/>
				</xsl:variable>
				<SEG TYPE="UNB">
					<ELEMENT>
						<FIELD>UNOY</FIELD>
						<FIELD>3</FIELD>
					</ELEMENT>
					<ELEMENT>
						<xsl:value-of select="$MessageSenderID"/>
					</ELEMENT>
					<ELEMENT>
						<FIELD>
							<xsl:value-of select="$S3-00010"/>
						</FIELD>
						<FIELD>01</FIELD>
						<FIELD>
							<xsl:value-of select="$S3-00014"/>
						</FIELD>
					</ELEMENT>
					<ELEMENT>
						<FIELD>
							<!--2019-10-04-->
							<xsl:value-of select="substring(replace($date, '-', ''), 3)"/>
						</FIELD>
						<FIELD>
							<!--13:38:35+02:00-->
							<xsl:value-of select="substring(replace($time, ':', ''), 1, 4)"/>
						</FIELD>						
					</ELEMENT>
					<ELEMENT>
						<xsl:value-of select="$MessageKey"/>
					</ELEMENT>
				</SEG>
				<SEG TYPE="UNH">
					<ELEMENT>
						<xsl:value-of select="PI_NUMBER"/>
					</ELEMENT>
					<ELEMENT>
						<FIELD>IFTSTA</FIELD>
						<FIELD>D</FIELD>
						<FIELD>96A</FIELD>
						<FIELD>UN</FIELD>
					</ELEMENT>
				</SEG>
				<SEG TYPE="BGM">
					<ELEMENT>
						<FIELD>
							<xsl:choose>
								<xsl:when test="$MessageTaskCode = 'IFTSTA24'">
									<xsl:text>44</xsl:text>
								</xsl:when>
								<xsl:otherwise>
									<xsl:text>23</xsl:text>
								</xsl:otherwise>
							</xsl:choose>
						</FIELD>
					</ELEMENT>
					<ELEMENT>1</ELEMENT>
					<ELEMENT>9</ELEMENT>
				</SEG>
				<SEG TYPE="DTM">
					<ELEMENT>
						<FIELD>137</FIELD>
						<FIELD>
							<xsl:value-of select="replace($date, '-', '')"/>
						</FIELD>
						<FIELD>102</FIELD>
					</ELEMENT>
				</SEG>
				<SEG TYPE="DTM">
					<ELEMENT>
						<FIELD>137</FIELD>
						<FIELD>
							<xsl:value-of select="substring(replace($time, ':', ''), 1, 6)"/>
						</FIELD>
						<FIELD>402</FIELD>
					</ELEMENT>
				</SEG>
				<xsl:if test="string-length(normalize-space(SLA_CODE)) gt 0">
					<SEG TYPE="TSR">
						<ELEMENT>
							<xsl:value-of select="tokenize(SLA_CODE, '-')[1]"/>
						</ELEMENT>
						<ELEMENT>
							<xsl:value-of select="tokenize(SLA_CODE, '-')[last()]"/>
						</ELEMENT>
					</SEG>
				</xsl:if>
				<xsl:for-each select="FMSDOM_PARTIES/FMSDOM_PARTY">
					<SEG TYPE="NAD">
						<ELEMENT>
							<xsl:value-of select="PARTY_QUALIFIER"/>
						</ELEMENT>
						<ELEMENT>
							<xsl:value-of select="THIRDPARTY_CODE"/>
						</ELEMENT>
						<ELEMENT>
							<xsl:value-of select="ADDRESS_NAME"/>
						</ELEMENT>
						<ELEMENT>
							<FIELD>
								<xsl:value-of select="THIRDPARTY_NAME"/>
							</FIELD>
							<FIELD/>
						</ELEMENT>
						<ELEMENT>
							<FIELD>
								<xsl:value-of select="normalize-space(concat(ADDRESS_STREET, ' ', ADDRESS_NBR, ' ', ADDRESS_BOX))"/>
							</FIELD>
							<FIELD/>
						</ELEMENT>
						<ELEMENT>
							<xsl:value-of select="ADDRESS_CITY"/>
						</ELEMENT>
						<ELEMENT/>
						<ELEMENT>
							<xsl:value-of select="ADDRESS_POSTAL_CODE"/>
						</ELEMENT>
						<ELEMENT>
							<xsl:value-of select="ADDRESS_COUNTRY"/>
						</ELEMENT>
					</SEG>
				</xsl:for-each>
				<SEG TYPE="RFF">
					<ELEMENT>
						<FIELD>SI</FIELD>
						<FIELD>
							<xsl:value-of select="tokenize(CUSTOMER_REFERENCE, 'BL')[1]"/>
						</FIELD>
					</ELEMENT>
				</SEG>
				<SEG TYPE="RFF">
					<ELEMENT>
						<FIELD>BN</FIELD>
						<FIELD>
							<xsl:value-of select="FMSDOM_TRANSPORTS/FMSDOM_TRANSPORT/CARRIER_BOOKING_NBR"/>
						</FIELD>
					</ELEMENT>
				</SEG>				
				<xsl:for-each select="FMSDOM_GOODS/FMSDOM_GOOD">
					<SEG TYPE="CNI">
						<ELEMENT>
							<xsl:value-of select="position()"/>
						</ELEMENT>
						<ELEMENT>
							<FIELD>
								<xsl:value-of select="GEN_UDF_INSTANCES/GEN_UDF_INSTANCE[UDF_CODE = 'GO_RFF-LI']/UDF_VALUE"/>	
							</FIELD>
							<FIELD/>
							<FIELD>
								<xsl:value-of select="GEN_UDF_INSTANCES/GEN_UDF_INSTANCE[UDF_CODE = 'GO_RFF-LI2']/UDF_VALUE"/>
							</FIELD>
						</ELEMENT>
					</SEG>
					<SEG TYPE="STS">
						<ELEMENT>1</ELEMENT>
						<ELEMENT>68</ELEMENT>
						<ELEMENT>8</ELEMENT>
					</SEG>
					<SEG TYPE="DTM">
						<ELEMENT>
							<FIELD>334</FIELD>
							<FIELD>
								<xsl:value-of select="replace($date, '-', '')"/>
							</FIELD>
							<FIELD>102</FIELD>
						</ELEMENT>
					</SEG>
					<SEG TYPE="DTM">
						<ELEMENT>
							<FIELD>334</FIELD>
							<FIELD>
								<xsl:value-of select="substring(replace($time, ':', ''), 1, 6)"/>
							</FIELD>
							<FIELD>402</FIELD>
						</ELEMENT>
					</SEG>
					
					<xsl:variable name="linkedTR">
						<xsl:for-each select="FMSDOM_GOOD_GIETS/FMSDOM_GOOD_GIET">
							<xsl:variable name="GIET" select="@RELATION_IDENTIFIER"/>
							<xsl:for-each select="../../../../FMSDOM_TRANSPORTS/FMSDOM_TRANSPORT[TRANSPORT_MODE = 'MAIN' and FMSDOM_TRANSPORT_GIETS/FMSDOM_TRANSPORT_GIET/@RELATION_IDENTIFIER = $GIET]">
								<xsl:copy-of select="."/>							
							</xsl:for-each>
						</xsl:for-each>
					</xsl:variable>
					<xsl:variable name="parties">
						<xsl:copy-of select="//FMSDOM_PARTIES"/>
					</xsl:variable>
					<xsl:for-each-group select="$linkedTR/FMSDOM_TRANSPORT" group-by="@KEY">	
						<SEG TYPE="TDT">
							<ELEMENT>21</ELEMENT>
							<ELEMENT>
								<xsl:value-of select="VOYAGE_NBR"/>
							</ELEMENT>
							<ELEMENT>10</ELEMENT>
							<ELEMENT>13</ELEMENT>
							<ELEMENT>
								<FIELD/>
								<FIELD/>
								<FIELD>11</FIELD>
								<FIELD>
									<xsl:variable name="supplier_party_id">
										<xsl:value-of select="SUPPLIER_PARTY_ID"/>
									</xsl:variable>
									<xsl:value-of select="$parties/FMSDOM_PARTIES/FMSDOM_PARTY[@KEY = $supplier_party_id]/THIRDPARTY_NAME"/>
								</FIELD>
							</ELEMENT>
							<ELEMENT/>
							<ELEMENT/>
							<ELEMENT>
								<FIELD>
									<xsl:value-of select="VESSEL_LLOYDS_NBR"/>
								</FIELD>
								<FIELD/>
								<FIELD/>
								<FIELD>
									<xsl:choose>
										<xsl:when test="string-length(normalize-space(VESSEL_NAME)) gt 0">
											<xsl:value-of select="VESSEL_NAME"/>
										</xsl:when>
										<xsl:otherwise>
											<xsl:value-of select="TRANSPORT_IDENTIFIER"/>
										</xsl:otherwise>
									</xsl:choose>
								</FIELD>
								<FIELD>
									<xsl:value-of select="VESSEL_COUNTRY"/>
								</FIELD>
							</ELEMENT>
						</SEG>
						<SEG TYPE="LOC">
							<ELEMENT>9</ELEMENT>
							<ELEMENT>
								<FIELD>
									<xsl:value-of select="FMSDOM_TRANSPORT_STOPS/FMSDOM_TRANSPORT_STOP[PLACE_QUALIFIER = '9']/LOCATION_OWNING_CODE"/>
								</FIELD>
								<FIELD/>
								<FIELD/>
								<FIELD>
									<xsl:value-of select="FMSDOM_TRANSPORT_STOPS/FMSDOM_TRANSPORT_STOP[PLACE_QUALIFIER = '9']/LOCATION_NAME"/>
								</FIELD>
							</ELEMENT>
						</SEG>
						<SEG TYPE="LOC">
							<ELEMENT>12</ELEMENT>
							<ELEMENT>
								<FIELD>
									<xsl:value-of select="FMSDOM_TRANSPORT_STOPS/FMSDOM_TRANSPORT_STOP[PLACE_QUALIFIER = '11']/LOCATION_OWNING_CODE"/>
								</FIELD>
								<FIELD/>
								<FIELD/>
								<FIELD>
									<xsl:value-of select="FMSDOM_TRANSPORT_STOPS/FMSDOM_TRANSPORT_STOP[PLACE_QUALIFIER = '11']/LOCATION_NAME"/>
								</FIELD>
							</ELEMENT>
						</SEG>
						<SEG TYPE="DTM">
							<ELEMENT>
								<FIELD>132</FIELD>
								<FIELD>
									<xsl:value-of select="replace(tokenize(FMSDOM_TRANSPORT_STOPS/FMSDOM_TRANSPORT_STOP[PLACE_QUALIFIER = '11']/START_TIME, 'T')[1], '-', '')"/>
								</FIELD>
								<FIELD>102</FIELD>
							</ELEMENT>
						</SEG>
						<SEG TYPE="DTM">
							<ELEMENT>
								<FIELD>186</FIELD>
								<FIELD>
									<xsl:value-of select="replace(tokenize(FMSDOM_TRANSPORT_STOPS/FMSDOM_TRANSPORT_STOP[PLACE_QUALIFIER = '9']/ACTUAL_TIME, 'T')[1], '-', '')"/>
								</FIELD>
								<FIELD>102</FIELD>
							</ELEMENT>
						</SEG>
					</xsl:for-each-group>
						
					<xsl:variable name="linkedCO">
						<xsl:for-each select="FMSDOM_GOOD_GIETS/FMSDOM_GOOD_GIET">
							<xsl:variable name="GIET" select="@RELATION_IDENTIFIER"/>
							<xsl:for-each select="../../../../FMSDOM_EQUIPMENTS/FMSDOM_EQUIPMENT[FMSDOM_EQUIPMENT_GIETS/FMSDOM_EQUIPMENT_GIET/@RELATION_IDENTIFIER = $GIET]">
								<xsl:copy-of select="."/>							
							</xsl:for-each>
						</xsl:for-each>
					</xsl:variable>
					<xsl:for-each-group select="$linkedCO/FMSDOM_EQUIPMENT" group-by="@KEY">	
						<SEG TYPE="EQD">
							<ELEMENT>CN</ELEMENT>
							<ELEMENT>
								<xsl:value-of select="EQUIPMENT_IDENTIFIER"/>
							</ELEMENT>
						</SEG>
					</xsl:for-each-group>
				</xsl:for-each>
			</EDIDOC>
		</xsl:for-each>
	</xsl:template>
</xsl:stylesheet>
