<?xml version="1.0"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:output encoding="UTF-8" method="text" version="1.0" indent="yes"/>
	<xsl:template match="dvanalyzer">
		<xsl:text>#frame_number,video_error_concealment_percentage,audio_error_channel_1_percentage,audio_error_channel_2_percentage,audio_error_head_difference&#10;</xsl:text>
		<xsl:for-each select="file/frames">
			<xsl:for-each select="frame">
				<xsl:value-of select="frame"/> 
				<xsl:text>,</xsl:text>
				<xsl:variable name='vid'><xsl:value-of select="substring-before(events/event[@event_type='video error concealment'],'%')"/></xsl:variable>
				<xsl:choose>
					<xsl:when test="$vid=''">
						<xsl:text>0</xsl:text>
					</xsl:when>
					<xsl:otherwise>
						<xsl:value-of select="$vid"/>
					</xsl:otherwise>
				</xsl:choose>
				<xsl:text>,</xsl:text>
				<xsl:variable name='ch1'><xsl:value-of select="substring-before(substring-after(events/event[@event_type='audio error code'],'CH1: '),' ')"/></xsl:variable>
				<xsl:choose>
					<xsl:when test="$ch1='no'">
						<xsl:text>100</xsl:text>
					</xsl:when>
					<xsl:when test="$ch1=''">
						<xsl:text>0</xsl:text>
					</xsl:when>
					<xsl:otherwise>
						<xsl:value-of select="substring-before($ch1,'%')"/>
					</xsl:otherwise>
				</xsl:choose>
				<xsl:text>,</xsl:text>
				<xsl:variable name='ch2'><xsl:value-of select="substring-before(substring-after(events/event[@event_type='audio error code'],'CH2: '),' ')"/></xsl:variable>
				<xsl:choose>
					<xsl:when test="$ch2='no'">
						<xsl:text>100</xsl:text>
					</xsl:when>
					<xsl:when test="$ch2=''">
						<xsl:text>0</xsl:text>
					</xsl:when>
					<xsl:otherwise>
						<xsl:value-of select="substring-before($ch2,'%')"/>
					</xsl:otherwise>
				</xsl:choose>
				<xsl:text>,</xsl:text>
				<xsl:variable name='ch_diff'><xsl:value-of select="substring-before($ch2,'%') - substring-before($ch1,'%')"/></xsl:variable>
				<xsl:choose>
					<xsl:when test="$ch_diff='NaN'">
						<xsl:text>0</xsl:text>
					</xsl:when>
					<xsl:otherwise>
						<xsl:value-of select="$ch_diff"/>
					</xsl:otherwise>
				</xsl:choose>
				<xsl:text>&#10;</xsl:text>
			</xsl:for-each>
		</xsl:for-each>
	</xsl:template>
</xsl:stylesheet>