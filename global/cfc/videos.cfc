<!---
*
* Copyright (C) 2005-2008 Razuna
*
* This file is part of Razuna - Enterprise Digital Asset Management.
*
* Razuna is free software: you can redistribute it and/or modify
* it under the terms of the GNU Affero Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.
*
* Razuna is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU Affero Public License for more details.
*
* You should have received a copy of the GNU Affero Public License
* along with Razuna. If not, see <http://www.gnu.org/licenses/>.
*
* You may restribute this Program with a special exception to the terms
* and conditions of version 3.0 of the AGPL as described in Razuna's
* FLOSS exception. You should have received a copy of the FLOSS exception
* along with Razuna. If not, see <http://www.razuna.com/licenses/>.
*
--->
<cfcomponent extends="extQueryCaching">

<!--- Get the cachetoken for here --->
<cfset variables.cachetoken = getcachetoken("videos")>

<!--- COUNT ALL VIDEOS IN A FOLDER --->
<cffunction name="getFolderCount" description="COUNT ALL VIDEOS IN A FOLDER" output="false" access="public" returntype="numeric">
	<cfargument name="folder_id" required="true" type="string">
	<cfargument name="file_extension" required="false" type="string" default="">
	<!--- init local vars --->
	<cfset var qLocal = 0>
	<cfquery datasource="#Variables.dsn#" name="qLocal" cachedwithin="1" region="razcache">
	SELECT /* #variables.cachetoken#getFolderCountvid */ COUNT(*) AS folderCount
	FROM #session.hostdbprefix#videos
	WHERE folder_id_r = <cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#Arguments.folder_id#">
	AND (vid_group IS NULL OR vid_group = '')
	AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
	</cfquery>
		<!--- todo : filter for file-extension --->
	<cfreturn qLocal.folderCount />
</cffunction>

<!--- GET ALL RECORDS OF THIS TYPE IN A FOLDER --->
<cffunction name="getFolderAssets" access="public" description="GET ALL RECORDS OF THIS TYPE IN A FOLDER" output="false" returntype="query">
	<cfargument name="folder_id" type="string" required="true">
	<cfargument name="ColumnList" required="false" type="string" hint="the column list for the selection" default="vid_id">
	<cfargument name="file_extension" required="false" type="string" default="">
	<cfargument name="offset" type="numeric" required="false" default="0">
	<cfargument name="rowmaxpage" type="numeric" required="false" default="0">
	<cfargument name="thestruct" type="struct" required="false" default="">
	<!--- init local vars --->
	<cfset qLocal = 0>
	<!--- Set pages var --->
	<cfparam name="arguments.thestruct.pages" default="">
	<cfparam name="arguments.thestruct.thisview" default="">
	<!--- If we need to show subfolders --->
	<cfif session.showsubfolders EQ "T">
		<cfinvoke component="folders" method="getfoldersinlist" dsn="#variables.dsn#" folder_id="#arguments.folder_id#" database="#variables.database#" hostid="#session.hostid#" returnvariable="thefolders">
		<cfset thefolderlist = arguments.folder_id & "," & ValueList(thefolders.folder_id)>
	<cfelse>
		<cfset thefolderlist = arguments.folder_id & ",">
	</cfif>
	<!--- Set the session for offset correctly if the total count of assets in lower the the total rowmaxpage --->
	<cfif arguments.thestruct.qry_filecount LTE session.rowmaxpage>
		<cfset session.offset = 0>
	</cfif>
	<!--- 
	This is for Oracle and MSQL
	Calculate the offset .Show the limit only if pages is null or current (from print) 
	--->
	<cfif arguments.thestruct.pages EQ "" OR arguments.thestruct.pages EQ "current">
		<cfif session.offset EQ 0>
			<cfset var min = 0>
			<cfset var max = session.rowmaxpage>
		<cfelse>
			<cfset var min = session.offset * session.rowmaxpage>
			<cfset var max = (session.offset + 1) * session.rowmaxpage>
			<cfif variables.database EQ "db2">
				<cfset min = min + 1>
			</cfif>
		</cfif>
	<cfelse>
		<cfset var min = 0>
		<cfset var max = 1000>
	</cfif>
	<!--- Set sortby variable --->
	<cfset var sortby = session.sortby>
	<!--- Set the order by --->
	<cfif session.sortby EQ "name" OR session.sortby EQ "kind">
		<cfset var sortby = "filename_forsort">
	<cfelseif session.sortby EQ "sizedesc">
		<cfset var sortby = "size DESC">
	<cfelseif session.sortby EQ "sizeasc">
		<cfset var sortby = "size ASC">
	<cfelseif session.sortby EQ "dateadd">
		<cfset var sortby = "date_create DESC">
	<cfelseif session.sortby EQ "datechanged">
		<cfset var sortby = "date_change DESC">
	</cfif>
	<!--- Oracle --->
	<cfif variables.database EQ "oracle">
		<!--- Clean columnlist --->
		<cfset var thecolumnlist = replacenocase(arguments.columnlist,"v.","","all")>
		<!--- Query --->
		<cfquery datasource="#Variables.dsn#" name="qLocal" cachedwithin="1" region="razcache">
		SELECT /* #variables.cachetoken#getFolderAssetsvid */ rn, #thecolumnlist#, keywords, description, labels, filename_forsort, size, hashtag, date_create, date_change
		FROM (
			SELECT ROWNUM AS rn, #thecolumnlist#, keywords, description, labels, filename_forsort, size, hashtag, date_create, date_change
			FROM (
				SELECT #Arguments.ColumnList#, vt.vid_keywords keywords, vt.vid_description description, '' as labels, lower(v.vid_filename) filename_forsort, v.vid_size size, v.hashtag, v.vid_create_time date_create, v.vid_change_time date_change
				FROM #session.hostdbprefix#videos v LEFT JOIN #session.hostdbprefix#videos_text vt ON v.vid_id = vt.vid_id_r AND vt.lang_id_r = 1
				WHERE v.folder_id_r IN (<cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#thefolderlist#" list="true">)
				AND (v.vid_group IS NULL OR v.vid_group = '')
				AND v.host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
				ORDER BY #sortby#
				)
			WHERE ROWNUM <= <cfqueryparam cfsqltype="cf_sql_numeric" value="#max#">
			)
		WHERE rn > <cfqueryparam cfsqltype="cf_sql_numeric" value="#min#">
		</cfquery>
	<!--- DB2 --->
	<cfelseif variables.database EQ "db2">
		<!--- Clean columnlist --->
		<cfset var thecolumnlist = replacenocase(arguments.columnlist,"v.","","all")>
		<!--- Query --->
		<cfquery datasource="#Variables.dsn#" name="qLocal" cachedwithin="1" region="razcache">
		SELECT /* #variables.cachetoken#getFolderAssetsvid */ #thecolumnlist#, vt.vid_keywords keywords, vt.vid_description description, '' as labels, filename_forsort, size, hashtag, date_create, date_change
		FROM (
			SELECT row_number() over() as rownr, v.*, vt.*, 
			lower(v.vid_filename) filename_forsort, v.vid_size size, v.hashtag, v.vid_create_time date_create, v.vid_change_time date_change
			FROM #session.hostdbprefix#videos v LEFT JOIN #session.hostdbprefix#videos_text vt ON v.vid_id = vt.vid_id_r AND vt.lang_id_r = 1
			WHERE v.folder_id_r IN (<cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#thefolderlist#" list="true">)
			AND (v.vid_group IS NULL OR v.vid_group = '')
			AND v.host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
			ORDER BY #sortby#
		)
		<!--- Show the limit only if pages is null or current (from print) --->
		<cfif arguments.thestruct.pages EQ "" OR arguments.thestruct.pages EQ "current">
			WHERE rownr between #min# AND #max#
		</cfif>
		</cfquery>
	<!--- Other DB's --->
	<cfelse>
		<!--- MySQL Offset --->
		<cfset var mysqloffset = session.offset * session.rowmaxpage>
		<!--- Query --->
		<cfquery datasource="#Variables.dsn#" name="qLocal" cachedwithin="1" region="razcache">
		SELECT /* #variables.cachetoken#getFolderAssetsvid */ <cfif variables.database EQ "mssql" AND (arguments.thestruct.pages EQ "" OR arguments.thestruct.pages EQ "current")>TOP #max# </cfif>#Arguments.ColumnList#, vt.vid_keywords keywords, vt.vid_description description, '' as labels, lower(v.vid_filename) filename_forsort, v.vid_size size, v.hashtag, v.vid_create_time date_create, v.vid_change_time date_change
		FROM #session.hostdbprefix#videos v LEFT JOIN #session.hostdbprefix#videos_text vt ON v.vid_id = vt.vid_id_r AND vt.lang_id_r = 1
		WHERE v.folder_id_r IN (<cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#thefolderlist#" list="true">)
		AND (v.vid_group IS NULL OR v.vid_group = '')
		AND v.host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
		<!--- MSSQL --->
		<cfif variables.database EQ "mssql" AND (arguments.thestruct.pages EQ "" OR arguments.thestruct.pages EQ "current")>
			AND v.vid_id NOT IN (
				SELECT TOP #min# vid_id
				FROM #session.hostdbprefix#videos
				WHERE folder_id_r IN (<cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#thefolderlist#" list="true">)
				AND (vid_group IS NULL OR vid_group = '')
				AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
			)
		</cfif>
		ORDER BY #sortby#
		<!--- Show the limit only if pages is null or current (from print) --->
		<cfif arguments.thestruct.pages EQ "" OR arguments.thestruct.pages EQ "current">
			<cfif variables.database EQ "mysql" OR variables.database EQ "h2">
				LIMIT #mysqloffset#, #session.rowmaxpage#
			</cfif>
		</cfif>
		</cfquery>
	</cfif>
	<!--- If coming from custom view and the session.customfileid is not empty --->
	<cfif session.customfileid NEQ "">
		<cfquery dbtype="query" name="qLocal">
		SELECT *
		FROM qLocal
		WHERE vid_id IN (<cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#session.customfileid#" list="true">)
		</cfquery>
	</cfif>
	<!--- Only get the labels if in the combinded view --->
	<cfif session.view EQ "combined">
		<!--- Get the cachetoken for here --->
		<cfset variables.cachetokenlabels = getcachetoken("labels")>
		<!--- Loop over files and get labels and add to qry --->
		<cfloop query="qLocal">
			<!--- Query labels --->
			<cfquery name="qry_l" datasource="#application.razuna.datasource#" cachedwithin="1" region="razcache">
			SELECT /* #variables.cachetokenlabels#getallassetslabels */ ct_label_id
			FROM ct_labels
			WHERE ct_id_r = <cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#vid_id#">
			</cfquery>
			<!--- Add labels query --->
			<cfset QuerySetCell(qLocal, "labels", valueList(qry_l.ct_label_id), currentRow)>
		</cfloop>
	</cfif>
	<!--- Return --->
	<cfreturn qLocal />
</cffunction>

<!--- GET ALL RECORD-DETAILS OF THIS TYPE IN A FOLDER --->
<cffunction name="getFolderAssetDetails" access="public" description="GET ALL RECORD-DETAILS OF THIS TYPE IN A FOLDER" output="false" returntype="query">
	<cfargument name="folder_id" type="string" required="true">
	<cfargument name="ColumnList" required="false" type="string" hint="the column list for the selection" default="v.vid_id, v.vid_filename, v.folder_id_r, v.vid_custom_id, v.vid_extension, v.vid_online, v.vid_owner, v.vid_create_date, v.vid_create_time, v.vid_change_date, v.vid_change_time, v.vid_mimetype, v.vid_publisher, v.vid_ranking rank, v.vid_single_sale, v.vid_is_new, v.vid_selection, v.vid_in_progress, v.vid_license, v.path_to_asset, v.cloud_url">
	<cfargument name="file_extension" type="string" required="false" default="">
	<cfargument name="offset" type="numeric" required="false" default="0">
	<cfargument name="rowmaxpage" type="numeric" required="false" default="0">
	<cfargument name="thestruct" type="struct" required="false" default="">
	<!--- Set thestruct if not here --->
	<cfif NOT isstruct(arguments.thestruct)>
		<cfset arguments.thestruct = structnew()>
	</cfif>
	<cfreturn getFolderAssets(folder_id=Arguments.folder_id, ColumnList=Arguments.ColumnList, file_extension=Arguments.file_extension, offset=session.offset, rowmaxpage=session.rowmaxpage, thestruct=arguments.thestruct)>
</cffunction>

<!--- GET DETAIL OF THIS VIDEO --->
<cffunction name="getdetails" access="public" output="false" returntype="query">
	<cfargument name="vid_id" type="string" required="true">
	<cfargument name="ColumnList" required="false" type="string" hint="the column list for the selection" default="v.vid_id, v.vid_filename, v.vid_custom_id, v.vid_extension, v.vid_mimetype, v.vid_preview_width, v.vid_preview_heigth, v.folder_id_r, v.vid_name_org, v.vid_name_image, v.vid_name_pre, v.vid_name_pre_img, v.vid_width vwidth, v.vid_height vheight, v.path_to_asset, v.cloud_url, v.cloud_url_org, v.vid_group">
	<!--- Local Param --->
	<cfset var qry = 0>
	<cfparam default="0" name="session.thegroupofuser">
	<!--- Get the cachetoken for here --->
	<cfset variables.cachetoken = getcachetoken("videos")>
	<!--- Query --->
	<cfquery datasource="#application.razuna.datasource#" name="qry" cachedwithin="1" region="razcache">
	SELECT /* #variables.cachetoken#getdetailsvid */ #arguments.columnlist#,
	<cfif listfind(session.thegroupofuser,"1",",") NEQ 0 OR listfind(session.thegroupofuser,"2",",") NEQ 0>
		'unlocked' as perm
	<cfelse>
		CASE
			<!--- Check permission on this folder --->
			WHEN EXISTS(
				SELECT fg.folder_id_r
				FROM #session.hostdbprefix#folders_groups fg
				WHERE fg.host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
				AND fg.folder_id_r = v.folder_id_r
				AND lower(fg.grp_permission) IN (<cfqueryparam cfsqltype="cf_sql_varchar" value="w,x" list="true">)
				AND fg.grp_id_r IN (<cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#session.thegroupofuser#" list="true">)
				) THEN 'unlocked'
			<!--- When folder is shared for everyone --->
			WHEN EXISTS(
				SELECT fg2.folder_id_r
				FROM #session.hostdbprefix#folders_groups fg2
				WHERE fg2.grp_id_r = '0'
				AND fg2.folder_id_r = v.folder_id_r
				AND fg2.host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
				AND lower(fg2.grp_permission) IN (<cfqueryparam cfsqltype="cf_sql_varchar" value="r,w,x" list="true">)
				) THEN 'unlocked'
			WHEN lower(v.vid_owner) = (
				SELECT lower(fo.folder_of_user) 
				FROM #session.hostdbprefix#folders fo 
				WHERE lower(fo.folder_of_user) = <cfqueryparam cfsqltype="cf_sql_varchar" value="t"> 
				AND fo.folder_owner = <cfqueryparam cfsqltype="cf_sql_varchar" value="#session.theuserid#">
				AND fo.folder_id = v.folder_id_r
				) THEN 'unlocked'
			ELSE 'locked'
		END as perm
	</cfif>
	FROM #session.hostdbprefix#videos v
	WHERE v.vid_id = <cfqueryparam value="#arguments.vid_id#" cfsqltype="CF_SQL_VARCHAR">
	AND v.host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
	</cfquery>
	<!--- Return --->
	<cfreturn qry>
</cffunction>

<!--- SHOW VIDEO --->
<cffunction hint="SHOW VIDEO" name="showvideo" output="true">
	<cfargument name="thestruct" type="struct">
	<cfargument name="thepath" default="" required="no" type="string">
	<cfargument name="thewebroot" default="" required="no" type="string">
	<cfset randomvalue = createuuid()>
	<cfparam name="arguments.thestruct.v" default="p">
	<!--- Now show the video file according to extension. If it is a preview movie then set the extension always to MOV --->
	<cfif arguments.thestruct.videofield EQ "video_preview" OR arguments.thestruct.v EQ "p">
		<cfset theextension = "mov">
	<cfelse>
		<cfset theextension = "#arguments.thestruct.videodetails.vid_extension#">
	</cfif>
	<!--- File System --->
	<cfif #arguments.thestruct.videofield# EQ "video_preview" OR arguments.thestruct.v EQ "p">
		<cfset thevideofile = arguments.thestruct.videodetails.vid_name_pre>
		<cfset thevideoimg = arguments.thestruct.videodetails.vid_name_pre_img>
	<cfelse>
		<cfset thevideofile = arguments.thestruct.videodetails.vid_name_org>
		<cfset thevideoimg = arguments.thestruct.videodetails.vid_name_image>
	</cfif>
	<!--- Storage Decision --->
	<cfset thestorage = "#session.thehttp##cgi.http_host##arguments.thestruct.dynpath#/assets/#session.hostid#/">
	<cfset thestoragefullpath = "#arguments.thestruct.assetpath#/#session.hostid#/">
	<!--- Set the correct path --->
	<cfset theimage = "#thestorage##arguments.thestruct.videodetails.path_to_asset#/#thevideoimg#">
	<cfset thevideo = "#thestorage##arguments.thestruct.videodetails.path_to_asset#/#thevideofile#">
	<!--- Nirvanix / Amazon --->
	<cfif application.razuna.storage EQ "amazon" OR application.razuna.storage EQ "nirvanix">
		<cfset theimage = arguments.thestruct.videodetails.cloud_url>
		<cfset thevideo = arguments.thestruct.videodetails.cloud_url_org>
	<!--- Akamai --->
	<cfelseif application.razuna.storage EQ "akamai">
		<cfset thevideo = arguments.thestruct.akaurl & arguments.thestruct.akavid & "/" & thevideofile>
	</cfif>
	<!--- Now show video according to extension --->
	<cfswitch expression="#theextension#">
	<!--- Flowplayer compatible formats --->
		<cfcase value="3gp,mpg4,swf,flv,f4v">
			<cfsavecontent variable="thevideo"><cfoutput><div style="height:auto;width:auto;padding-top:50px;"><a class="flowplayerdetail" href="#thevideo#" style="height:#arguments.thestruct.videodetails.vheight#px;width:#arguments.thestruct.videodetails.vwidth#px;"><img src="#theimage#" border="0" width="#arguments.thestruct.videodetails.vwidth#" height="#arguments.thestruct.videodetails.vheight#"></a>
			<script language="javascript" type="text/javascript">
				// Initiate
				flowplayer("a.flowplayerdetail", "#arguments.thestruct.dynpath#/global/videoplayer/flowplayer-3.2.7.swf", { 
				    clip: {
				    	autoBuffering: true, 
				    	autoplay: true, 
				    plugins: { 
				        controls: { 
				            all: false,  
				            play: true,  
				            scrubber: true,
				            volume: true,
				            mute: true,
				            time: true,
				            stop: true,
				            fullscreen: true
				        }
				    }
				}});
			</script><br>Click on the image above to start watching the movie.<br>(If the video is not showing try to <a href="#thevideo#">watch it in QuickTime directly</a>.)</div></cfoutput>
			</cfsavecontent>
		</cfcase>
		<!--- Quicktime only MOV --->
		<cfcase value="mov,mpg,m4v">
			<cflocation url="#thevideo#">
			<!--- <cfset theheight = #arguments.thestruct.videodetails.vheight# + 16>
			<cfset thewidth = #arguments.thestruct.videodetails.vwidth#>
			<cfsavecontent variable="thevideo"><cfoutput>
			<script type="text/javascript">
			    QT_WriteOBJECT('#thevideo#', '#thewidth#','#theheight#', '', 
			     'scale', 'tofit',
			     'controller','true',
			     'autoplay','true'
			     );
			</script>
			</cfoutput></cfsavecontent> --->
			<!--- <cfif cgi.user_agent CONTAINS "safari" AND NOT cgi.user_agent CONTAINS "chrome">
				<video controls="" autoplay="" style="margin: auto; position: absolute; top: 0; right: 0; bottom: 0; left: 0;" name="media" src="#thevideo#"></video>
			<cfelse>
				<OBJECT CLASSID="clsid:02BF25D5-8C17-4B23-BC80-D3488ABDDC6B" HEIGHT="#theheight#" WIDTH="#thewidth#" CODEBASE="http://www.apple.com/qtactivex/qtplugin.cab">
				
				<PARAM NAME="src" VALUE="#theimage#" >
				<PARAM NAME="autoplay" VALUE="true" >
				<PARAM NAME="HREF" VALUE="#thevideo#" >
				<PARAM NAME="TARGET" VALUE="myself" >
				<!--- The Embed code --->
				<embed width="#thewidth#" height="#theheight#" name="plugin" autoplay="true" src="#theimage#" href="#thevideo#" target="myself" type="video/quicktime" pluginspage="http://www.apple.com/quicktime/download/"> 
				</OBJECT>
			</cfif>
			<br>Click on the image to start watching the movie.<br>(If the video is not showing try to <a href="#thevideo#">watch it in QuickTime directly</a>.) --->
			<!--- Add 16pixel to the heigth or else the controller of the quicktime can not be seen --->
			<!---
<cfset theheight = #arguments.thestruct.videodetails.vheight# + 16>
			<cfset thewidth = #arguments.thestruct.videodetails.vwidth#>
			<cfsavecontent variable="thevideo"><cfoutput>
			<script language="JavaScript" type="text/javascript">
			QT_WriteOBJECT('#theimage#','#thewidth#','#theheight#','',
			'href','#thevideo#',
			'target','myself',
			'type','video/quicktime',
			'controller','false',
			'autoplay', 'true',
			'scale','tofit',
			'loop','false',
			'bgcolor','##FFFFFF',
			'kioskmode','false',
			'EnableJavaScript', 'True',
			'postdomevents', 'True',
			'emb##NAME', 'movie#arguments.thestruct.vid_id#', 
			'obj##id', 'movie#arguments.thestruct.vid_id#', 
			'emb##id', 'movie_embed#arguments.thestruct.vid_id#',
			'movieid','#arguments.thestruct.vid_id#');
			</script>
			<br>Click on the image above to start watching the movie.<br>(If the video is not showing try to <a href="#thevideo#">watch it in QuickTime directly</a>.)</cfoutput>
			</cfsavecontent> --->
		</cfcase>
		<!--- MP4 / HTML5 --->
		<cfcase value="ogv,webm,mp4">
			<cfif cgi.HTTP_USER_AGENT CONTAINS "Firefox">
				<cflocation url="#thevideo#" />
			<cfelse>
				<cfsavecontent variable="thevideo"><cfoutput>
				If the video does not play properly try to <a href="#thevideo#">watch it directly</a>.<br>
				<video autoplay="true" controls="true" style="margin: auto; position: absolute; top: 0; right: 0; bottom: 0; left: 0;" name="media">
					<cfif theextension EQ "ogv">
						<source src="#thevideo#" type="video/ogg" />
					<cfelseif theextension EQ "webm">
						<source src="#thevideo#" type="video/webm" />
					<cfelseif theextension EQ "mp4">
						<source src="#thevideo#" type="video/mp4" />
					</cfif>
				<video>
				</cfoutput></cfsavecontent>
			</cfif>
		</cfcase>
		<!--- WMV --->
		<cfcase value="wmv,avi">
			<!--- Add 16pixel to the heigth or else the controller of the quicktime can not be seen --->
			<cfif #arguments.thestruct.videofield# EQ "video" OR arguments.thestruct.v EQ "o">
				<cfset theheight = #arguments.thestruct.videodetails.vheight# + 16>
				<cfset thewidth = #arguments.thestruct.videodetails.vwidth#>
			<cfelse>
				<cfset theheight = #arguments.thestruct.videodetails.vid_preview_heigth# + 16>
				<cfset thewidth = #arguments.thestruct.videodetails.vid_preview_width#>
			</cfif>
			<cfset theheight = #arguments.thestruct.videodetails.vheight# + 16>
			<cfset thewidth = #arguments.thestruct.videodetails.vwidth#>
			<!--- For Windows --->
			<cfif cgi.HTTP_USER_AGENT CONTAINS "windows">
				<cfsavecontent variable="thevideo"><cfoutput>
<object id="MediaPlayer" width="#thewidth#" height="#theheight#" classid="CLSID:22D6F312-B0F6-11D0-94AB-0080C74C7E95" standby="Loading Microsoft Windows Media Player components..." type="application/x-oleobject" codebase="http://activex.microsoft.com/activex/controls/mplayer/en/nsmp2inf.cab##Version=6,4,7,1112">
   <param name="filename" value="#thevideo#">
   <param name="autoStart" value="true">           
   <param name="showControls" value="true">
   <param name="ShowStatusBar" value="true">
   <param name="Autorewind" value="true">
   <param name="ShowDisplay" value="false">
   <embed src="#thevideo#" width="#thewidth#" height="#theheight#" type="application/x-mplayer2" name="MediaPlayer" autostart="1" showcontrols="0" showstatusbar="1" autorewind="1" showdisplay="0"></embed>
</object></cfoutput></cfsavecontent>
			<!--- Else we use Quicktime --->
			<cfelse>
				<!--- For Mac we simply redirect to the source. If user has Flip4Mac installed it will start playing in the browser --->
				<cflocation url="#thevideo#">
			</cfif>
		</cfcase>
		<!--- RPM - RM --->
		<cfcase value="rm">
			<!--- Add 16pixel to the heigth or else the controller of the quicktime can not be seen --->
			<cfif #arguments.thestruct.videofield# EQ "video" OR arguments.thestruct.v EQ "o">
			<cfset theheight = #arguments.thestruct.videodetails.vheight#>
			<cfset thewidth = #arguments.thestruct.videodetails.vwidth#>
			<cfelse>
			<cfset theheight = #arguments.thestruct.videodetails.vid_preview_heigth#>
			<cfset thewidth = #arguments.thestruct.videodetails.vid_preview_width#>
			</cfif>
			<cfsavecontent variable="thevideo"><cfoutput>
<EMBED WIDTH=#thewidth# HEIGHT=#theheight# SRC="#thevideo#" CONTROLS=ImageWindow CONSOLE=one></cfoutput>
			</cfsavecontent>
		</cfcase>
		<!--- THESE FILES WILL BE DOWNLOADED --->
		<cfdefaultcase>
			<!--- Just redirect to the download page for videos --->
			<cflocation url="index.cfm?fa=c.serve_file&file_id=#arguments.thestruct.vid_id#&type=vid">
		</cfdefaultcase>
	</cfswitch>
<cfreturn thevideo>
</cffunction>

<!--- GET RELATED VIDEOS --->
<cffunction name="relatedvideos" output="true">
	<cfargument name="thestruct" type="struct">
	<!--- Get the cachetoken for here --->
	<cfset variables.cachetoken = getcachetoken("videos")>
	<!--- Query --->
	<cfquery datasource="#variables.dsn#" name="qry" cachedwithin="1" region="razcache">
	SELECT /* #variables.cachetoken#relatedvideosvid */ v.vid_id, v.folder_id_r, v.vid_filename, v.vid_extension, 
	v.vid_height, v.vid_width, v.vid_size vlength, v.vid_name_org, v.path_to_asset, v.cloud_url_org, v.vid_group
	FROM #session.hostdbprefix#videos v
	WHERE v.vid_group = <cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#arguments.thestruct.file_id#">
	AND v.host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
	ORDER BY vid_extension
	</cfquery>
	<cfreturn qry>
</cffunction>

<!--- THREAD: CREATE THE PREVIEW IMAGE AND VIDEO --------------------------------------------------------->
<cffunction name="create_previews" output="true">
	<cfargument name="thestruct" type="struct">
	<!--- If we are MP4 run it trough MP4Box --->
	<cfif arguments.thestruct.qryfile.extension EQ "mp4" AND arguments.thestruct.thetools.mp4box NEQ "">
		<cfset var ttmp4 = createuuid("")>
		<cfif arguments.thestruct.isWindows>
			<cfset arguments.thestruct.themp4 = "#arguments.thestruct.thetools.mp4box#/MP4Box.exe">
		<cfelse>
			<cfset arguments.thestruct.themp4 = "#arguments.thestruct.thetools.mp4box#/MP4Box">
		</cfif>
		<cfthread name="#ttmp4#" intstruct="#arguments.thestruct#">
			<cfexecute name="#attributes.intstruct.themp4#" arguments="-inter 500 #attributes.intstruct.thisvid.finalpath#/#attributes.intstruct.qryfile.filename#" timeout="9999" />
		</cfthread>
		<!--- Wait for the thread above until the file is fully converted --->
		<cfthread action="join" name="#ttmp4#" />
	</cfif>
	<!--- RFS --->
	<cfif !application.razuna.rfs>
		<cftry>
			<!--- Choose platform --->
			<cfif arguments.thestruct.isWindows>
				<cfset var theexe = """#arguments.thestruct.thetools.ffmpeg#/ffmpeg.exe""">
				<cfset var theasset = """#arguments.thestruct.thisvid.finalpath#/#arguments.thestruct.qryfile.filename#""">
				<cfset var theorg = """#arguments.thestruct.thetempdirectory#/#arguments.thestruct.thisvid.theorgimage#""">
				<cfset var theorgraw = "#arguments.thestruct.thetempdirectory#/#arguments.thestruct.thisvid.theorgimage#">
			<cfelse>
				<cfset var theexe = "#arguments.thestruct.thetools.ffmpeg#/ffmpeg">
				<cfset var themp4 = "#arguments.thestruct.thetools.mp4box#/MP4Box">
				<cfset var theasset = "#arguments.thestruct.thisvid.finalpath#/#arguments.thestruct.qryfile.filename#">
				<cfset var theorg = "#arguments.thestruct.thetempdirectory#/#arguments.thestruct.thisvid.theorgimage#">
				<cfset var theorgraw = "#arguments.thestruct.thetempdirectory#/#arguments.thestruct.thisvid.theorgimage#">
				<cfset theorg = replace(theorg," ","\ ","all")>
				<cfset theorg = replace(theorg,"&","\&","all")>
				<cfset theorg = replace(theorg,"'","\'","all")>
			</cfif>
			<!--- If linked asset --->
			<cfif arguments.thestruct.qryfile.link_kind EQ "lan">
				<cfif arguments.thestruct.isWindows>
					<cfset theasset = """#arguments.thestruct.qryfile.path#""">
				<cfelse>
					<cfset theasset = replace(arguments.thestruct.qryfile.path," ","\ ","all")>
					<cfset theasset = replace(theasset,"&","\&","all")>
					<cfset theasset = replace(theasset,"'","\'","all")>
				</cfif>
			</cfif>
			<!--- Write and execute script --->
			<cfset var thescript = arguments.thestruct.thisvid.newid>
			<cfset arguments.thestruct.thesh = gettempdirectory() & "/#thescript#p.sh">
			<!--- On Windows a bat --->
			<cfif arguments.thestruct.isWindows>
				<cfset arguments.thestruct.thesh = gettempdirectory() & "/#thescript#p.bat">
			</cfif>
			<!--- Write files --->
			<cffile action="write" file="#arguments.thestruct.thesh#" output="#theexe# -i #theasset# -vframes 1 -f image2 -vcodec mjpeg #theorg#" mode="777">
			<!--- Execute --->
			<cfthread name="#thescript#" intstruct="#arguments.thestruct#">
				<cfexecute name="#attributes.intstruct.thesh#" timeout="9000" />
			</cfthread>
			<!--- Wait for the thread above --->
			<cfthread action="join" name="#thescript#" />
			<!--- Delete scripts --->
			<cffile action="delete" file="#arguments.thestruct.thesh#">
			<!--- If we can't create a still image we resort to a placeholder image --->
			<cfif !FileExists("#theorgraw#")>
				<cffile action="copy" source="#arguments.thestruct.theplaceholderpic#" destination="#theorgraw#" mode="775">
			</cfif>
			<!--- If we are coming from a path and we are local we move the thumbnail to the final destination, else we leave it here for pickup --->
			<cfif arguments.thestruct.importpath AND application.razuna.storage EQ "local">
				<cffile action="move" source="#theorgraw#" destination="#arguments.thestruct.thisvid.finalpath#/#arguments.thestruct.thisvid.theorgimage#" mode="775" />
			</cfif>
			<!--- cfcatch --->
			<cfcatch type="any">
				<cfinvoke component="debugme" method="email_dump" emailto="nitai@razuna.com" emailfrom="server@razuna.com" emailsubject="debug" dump="#cfcatch#">
			</cfcatch>
		</cftry>
	</cfif>
	<cfreturn />
</cffunction>

<!--- REMOVE THE VIDEO --->
<cffunction hint="REMOVE THE VIDEO" name="removevideo" output="true">
	<cfargument name="thestruct" type="struct">
	<!--- Get file detail for log --->
	<cfinvoke method="getdetails" vid_id="#arguments.thestruct.id#" ColumnList="v.vid_filename, v.folder_id_r, v.vid_name_org filenameorg, v.vid_name_image, v.lucene_key, v.link_kind, v.link_path_url, v.path_to_asset, v.vid_group" returnvariable="thedetail">
	<!--- Execute workflow --->
	<cfset arguments.thestruct.fileid = arguments.thestruct.id>
	<cfset arguments.thestruct.file_name = thedetail.vid_filename>
	<cfset arguments.thestruct.thefiletype = "vid">
	<cfset arguments.thestruct.folder_id = thedetail.folder_id_r>
	<cfset arguments.thestruct.folder_action = false>
	<cfinvoke component="plugins" method="getactions" theaction="on_file_remove" args="#arguments.thestruct#" />
	<cfset arguments.thestruct.folder_action = true>
	<cfinvoke component="plugins" method="getactions" theaction="on_file_remove" args="#arguments.thestruct#" />
	<!--- Update main record with dates --->
	<cfinvoke component="global" method="update_dates" type="vid" fileid="#thedetail.vid_group#" />
	<!--- Log --->
	<cfinvoke component="extQueryCaching" method="log_assets">
		<cfinvokeargument name="theuserid" value="#session.theuserid#">
		<cfinvokeargument name="logaction" value="Delete">
		<cfinvokeargument name="logdesc" value="Deleted: #thedetail.vid_filename#">
		<cfinvokeargument name="logfiletype" value="vid">
		<cfinvokeargument name="assetid" value="#arguments.thestruct.id#">
	</cfinvoke>
	<!--- Delete from files DB (including referenced data)--->
	<cfquery datasource="#application.razuna.datasource#">
	DELETE FROM #session.hostdbprefix#videos
	WHERE vid_id = <cfqueryparam value="#arguments.thestruct.id#" cfsqltype="CF_SQL_VARCHAR">
	AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
	</cfquery>
	<!--- Delete from collection --->
	<cfquery datasource="#application.razuna.datasource#">
	DELETE FROM #session.hostdbprefix#collections_ct_files
	WHERE file_id_r = <cfqueryparam value="#arguments.thestruct.id#" cfsqltype="CF_SQL_VARCHAR">
	AND col_file_type = <cfqueryparam value="vid" cfsqltype="cf_sql_varchar">
	</cfquery>
	<!--- Delete from favorites --->
	<cfquery datasource="#application.razuna.datasource#">
	DELETE FROM #session.hostdbprefix#users_favorites
	WHERE fav_id = <cfqueryparam value="#arguments.thestruct.id#" cfsqltype="CF_SQL_VARCHAR">
	AND fav_kind = <cfqueryparam value="vid" cfsqltype="cf_sql_varchar">
	AND user_id_r = <cfqueryparam value="#session.theuserid#" cfsqltype="CF_SQL_VARCHAR">
	</cfquery>
	<!--- Delete from Versions --->
	<cfquery datasource="#application.razuna.datasource#">
	DELETE FROM #session.hostdbprefix#versions
	WHERE asset_id_r = <cfqueryparam value="#arguments.thestruct.id#" cfsqltype="CF_SQL_VARCHAR">
	AND ver_type = <cfqueryparam value="vid" cfsqltype="cf_sql_varchar">
	</cfquery>
	<!--- Delete from Share Options --->
	<cfquery datasource="#application.razuna.datasource#">
	DELETE FROM #session.hostdbprefix#share_options
	WHERE asset_id_r = <cfqueryparam value="#arguments.thestruct.id#" cfsqltype="CF_SQL_VARCHAR">
	</cfquery>
	<!--- Delete labels --->
	<cfinvoke component="labels" method="label_ct_remove" id="#arguments.thestruct.id#" />
	<!--- Custom field values --->
	<cfinvoke component="custom_fields" method="delete_values" fileid="#arguments.thestruct.id#" />
	<!--- Flush Cache --->
	<cfset variables.cachetoken = resetcachetoken("videos")>
	<cfset variables.cachetoken = resetcachetoken("folders")>
	<!--- Delete from file system --->
	<cfset arguments.thestruct.hostid = session.hostid>
	<cfset arguments.thestruct.folder_id_r = thedetail.folder_id_r>
	<cfset arguments.thestruct.qrydetail = thedetail>
	<cfset arguments.thestruct.link_kind = thedetail.link_kind>
	<cfset arguments.thestruct.filenameorg = thedetail.filenameorg>
	<cfthread intstruct="#arguments.thestruct#">
		<cfinvoke method="deletefromfilesystem" thestruct="#attributes.intstruct#">
	</cfthread>
	<cfreturn />
</cffunction>

<!--- REMOVE MANY VIDEO --->
<cffunction name="removevideomany" output="true">
	<cfargument name="thestruct" type="struct">
	<!--- Set Params --->
	<cfset session.hostdbprefix = arguments.thestruct.hostdbprefix>
	<cfset session.hostid = arguments.thestruct.hostid>
	<cfset session.theuserid = arguments.thestruct.theuserid>
	<cfparam name="arguments.thestruct.fromfolderremove" default="false" />
	<!--- Loop --->
	<cfloop list="#arguments.thestruct.id#" index="i" delimiters=",">
		<cfset i = listfirst(i,"-")>
		<!--- Get file detail for log --->
		<cfinvoke method="getdetails" vid_id="#i#" ColumnList="v.vid_filename, v.folder_id_r, v.vid_name_org filenameorg, v.vid_name_image, lucene_key, link_kind, link_path_url, path_to_asset" returnvariable="thedetail">
		<!--- Execute workflow --->
		<cfif !arguments.thestruct.fromfolderremove>
			<cfset arguments.thestruct.fileid = i>
			<cfset arguments.thestruct.file_name = thedetail.vid_filename>
			<cfset arguments.thestruct.thefiletype = "vid">
			<cfset arguments.thestruct.folder_id = thedetail.folder_id_r>
			<cfset arguments.thestruct.folder_action = false>
			<cfinvoke component="plugins" method="getactions" theaction="on_file_remove" args="#arguments.thestruct#" />
			<cfset arguments.thestruct.folder_action = true>
			<cfinvoke component="plugins" method="getactions" theaction="on_file_remove" args="#arguments.thestruct#" />
		</cfif>
		<!--- Log --->
		<cfinvoke component="extQueryCaching" method="log_assets">
			<cfinvokeargument name="theuserid" value="#session.theuserid#">
			<cfinvokeargument name="logaction" value="Delete">
			<cfinvokeargument name="logdesc" value="Deleted: #thedetail.vid_filename#">
			<cfinvokeargument name="logfiletype" value="vid">
			<cfinvokeargument name="assetid" value="#i#">
		</cfinvoke>
		<cftransaction>
			<!--- Delete from files DB (including referenced data)--->
			<cfquery datasource="#application.razuna.datasource#">
			DELETE FROM #arguments.thestruct.hostdbprefix#videos
			WHERE vid_id = <cfqueryparam value="#i#" cfsqltype="CF_SQL_VARCHAR">
			AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#arguments.thestruct.hostid#">
			</cfquery>
			<!--- Delete from collection --->
			<cfquery datasource="#application.razuna.datasource#">
			DELETE FROM #arguments.thestruct.hostdbprefix#collections_ct_files
			WHERE file_id_r = <cfqueryparam value="#i#" cfsqltype="CF_SQL_VARCHAR">
			AND col_file_type = <cfqueryparam value="vid" cfsqltype="cf_sql_varchar">
			</cfquery>
			<!--- Delete from favorites --->
			<cfquery datasource="#application.razuna.datasource#">
			DELETE FROM #arguments.thestruct.hostdbprefix#users_favorites
			WHERE fav_id = <cfqueryparam value="#i#" cfsqltype="CF_SQL_VARCHAR">
			AND fav_kind = <cfqueryparam value="vid" cfsqltype="cf_sql_varchar">
			AND user_id_r = <cfqueryparam value="#arguments.thestruct.theuserid#" cfsqltype="CF_SQL_VARCHAR">
			</cfquery>
			<!--- Delete from Versions --->
			<cfquery datasource="#application.razuna.datasource#">
			DELETE FROM #arguments.thestruct.hostdbprefix#versions
			WHERE asset_id_r = <cfqueryparam value="#i#" cfsqltype="CF_SQL_VARCHAR">
			AND ver_type = <cfqueryparam value="vid" cfsqltype="cf_sql_varchar">
			</cfquery>
			<!--- Delete from Share Options --->
			<cfquery datasource="#application.razuna.datasource#">
			DELETE FROM #arguments.thestruct.hostdbprefix#share_options
			WHERE asset_id_r = <cfqueryparam value="#i#" cfsqltype="CF_SQL_VARCHAR">
			</cfquery>
		</cftransaction>
		<!--- Delete labels --->
		<cfinvoke component="labels" method="label_ct_remove" id="#i#" />
		<!--- Custom field values --->
		<cfinvoke component="custom_fields" method="delete_values" fileid="#i#" />
		<!--- Delete from file system --->
		<cfset arguments.thestruct.id = i>
		<cfset arguments.thestruct.folder_id_r = thedetail.folder_id_r>
		<cfset arguments.thestruct.qrydetail = thedetail>
		<cfset arguments.thestruct.link_kind = thedetail.link_kind>
		<cfset arguments.thestruct.filenameorg = thedetail.filenameorg>
		<cfthread intstruct="#arguments.thestruct#">
			<cfinvoke method="deletefromfilesystem" thestruct="#attributes.intstruct#">
		</cfthread>
	</cfloop>
	<!--- Flush Cache --->
	<cfset variables.cachetoken = resetcachetoken("videos")>
	<cfset variables.cachetoken = resetcachetoken("folders")>
	<cfreturn />
</cffunction>

<!--- SubFunction called from deletion above --->
<cffunction name="deletefromfilesystem" output="false">
	<cfargument name="thestruct" type="struct">
	<cftry>
		<!--- Delete in Lucene --->
		<cfinvoke component="lucene" method="index_delete" thestruct="#arguments.thestruct#" assetid="#arguments.thestruct.id#" category="vid">
		<!--- Delete File --->
		<cfif application.razuna.storage EQ "local">
			<cfif DirectoryExists("#arguments.thestruct.assetpath#/#arguments.thestruct.hostid#/#arguments.thestruct.qrydetail.path_to_asset#") AND arguments.thestruct.qrydetail.path_to_asset NEQ "">
				<cfdirectory action="delete" directory="#arguments.thestruct.assetpath#/#arguments.thestruct.hostid#/#arguments.thestruct.qrydetail.path_to_asset#" recurse="true">
			</cfif>
			<!--- Versions --->
			<cfif DirectoryExists("#arguments.thestruct.assetpath#/#session.hostid#/versions/vid/#arguments.thestruct.id#") AND arguments.thestruct.id NEQ "">
				<cfdirectory action="delete" directory="#arguments.thestruct.assetpath#/#session.hostid#/versions/vid/#arguments.thestruct.id#" recurse="true">
			</cfif>
		<!--- Nirvanix --->
		<cfelseif application.razuna.storage EQ "nirvanix" AND arguments.thestruct.qrydetail.path_to_asset NEQ "">
			<cfinvoke component="nirvanix" method="DeleteFolders" nvxsession="#arguments.thestruct.nvxsession#" folderpath="/#arguments.thestruct.qrydetail.path_to_asset#">
			<!--- Versions --->
			<cfinvoke component="nirvanix" method="DeleteFolders" nvxsession="#arguments.thestruct.nvxsession#" folderpath="/versions/vid/#arguments.thestruct.id#">
		<!--- Amazon --->
		<cfelseif application.razuna.storage EQ "amazon" AND arguments.thestruct.qrydetail.path_to_asset NEQ "">
			<cfinvoke component="amazon" method="deletefolder" folderpath="#arguments.thestruct.qrydetail.path_to_asset#" awsbucket="#arguments.thestruct.awsbucket#" />
			<!--- Versions --->
			<cfinvoke component="amazon" method="deletefolder" folderpath="versions/vid/#arguments.thestruct.id#" awsbucket="#arguments.thestruct.awsbucket#" />
		<!--- Akamai --->
		<cfelseif application.razuna.storage EQ "akamai" AND arguments.thestruct.qrydetail.path_to_asset NEQ "">
			<cfinvoke component="akamai" method="Delete">
				<cfinvokeargument name="theasset" value="">
				<cfinvokeargument name="thetype" value="#arguments.thestruct.akavid#">
				<cfinvokeargument name="theurl" value="#arguments.thestruct.akaurl#">
				<cfinvokeargument name="thefilename" value="#arguments.thestruct.qrydetail.filenameorg#">
			</cfinvoke>
		</cfif>
		<!--- REMOVE RELATED FOLDERS ALSO!!!! --->
		<!--- Get all that have the same vid_id as related --->
		<cfquery datasource="#application.razuna.datasource#" name="qry">
		SELECT path_to_asset
		FROM #session.hostdbprefix#videos
		WHERE vid_group = <cfqueryparam value="#arguments.thestruct.id#" cfsqltype="CF_SQL_VARCHAR">
		AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
		</cfquery>
		<!--- Loop over the found records --->
		<cfloop query="qry">
			<cftry>
				<cfif application.razuna.storage EQ "local">
					<cfif DirectoryExists("#arguments.thestruct.assetpath#/#arguments.thestruct.hostid#/#path_to_asset#") AND path_to_asset NEQ "">
						<cfdirectory action="delete" directory="#arguments.thestruct.assetpath#/#arguments.thestruct.hostid#/#path_to_asset#" recurse="true">
					</cfif>
				<cfelseif application.razuna.storage EQ "nirvanix" AND path_to_asset NEQ "">
					<cfinvoke component="nirvanix" method="DeleteFolders" nvxsession="#arguments.thestruct.nvxsession#" folderpath="/#path_to_asset#">
				<cfelseif application.razuna.storage EQ "amazon" AND path_to_asset NEQ "">
					<cfinvoke component="amazon" method="deletefolder" folderpath="#path_to_asset#" awsbucket="#arguments.thestruct.awsbucket#" />
				</cfif>
				<cfcatch type="any"></cfcatch>
			</cftry>
		</cfloop>
		<!--- Delete related videos as well --->
		<cfquery datasource="#application.razuna.datasource#">
		DELETE FROM #session.hostdbprefix#videos
		WHERE vid_group = <cfqueryparam value="#arguments.thestruct.id#" cfsqltype="CF_SQL_VARCHAR">
		AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
		</cfquery>
		<cfcatch type="any">
			<cfinvoke component="debugme" method="email_dump" emailto="support@razuna.com" emailfrom="server@razuna.com" emailsubject="Error on removing a video from system (HostID: #arguments.thestruct.hostid#, Asset: #arguments.thestruct.id#)" dump="#cfcatch#">
		</cfcatch>
	</cftry>
	<cfreturn />
</cffunction>

<!--- GET THE VIDEO DETAILS FOR BASKET --->
<cffunction name="detailforbasket" output="false">
	<cfargument name="thestruct" type="struct">
	<!--- Param --->
	<cfparam default="F" name="arguments.thestruct.related">
	<cfparam default="0" name="session.thegroupofuser">
	<!--- Qry. We take the query and do a IN --->
	<cfquery datasource="#variables.dsn#" name="qry" cachedwithin="1" region="razcache">
	SELECT /* #variables.cachetoken#detailforbasketvid */ v.vid_id, v.vid_filename filename, v.vid_extension, v.vid_mimetype, v.vid_group, v.vid_preview_width, 
	v.vid_preview_heigth, v.folder_id_r, v.vid_width vwidth, v.vid_height vheight, v.vid_size vlength, 
	v.vid_prev_size vprevlength, v.vid_name_image, v.link_kind, v.link_path_url, v.path_to_asset, v.cloud_url,
	'' as perm
	FROM #session.hostdbprefix#videos v
	WHERE 
	<cfif arguments.thestruct.related EQ "T">
		v.vid_group
	<cfelse>
		v.vid_id
	</cfif>
	<cfif arguments.thestruct.qrybasket.recordcount EQ 0>
		= '0'
	<cfelse>
		IN (<cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#ValueList(arguments.thestruct.qrybasket.cart_product_id)#" list="true">)
	</cfif>
	AND v.host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
	</cfquery>
	<!--- Get proper folderaccess --->
	<cfloop query="qry">
		<cfinvoke component="folders" method="setaccess" returnvariable="theaccess" folder_id="#folder_id_r#"  />
		<!--- Add labels query --->
		<cfset QuerySetCell(qry, "perm", theaccess, currentRow)>
	</cfloop>
	<cfreturn qry>
</cffunction>

<!--- GET THE VIDEO DETAILS --->
<cffunction name="detail" output="false">
	<cfargument name="thestruct" type="struct">
	<!--- Params --->
	<cfset var qry = structnew()>
	<!--- Get details --->
	<cfquery datasource="#variables.dsn#" name="details" cachedwithin="1" region="razcache">
	SELECT /* #variables.cachetoken#detailvid */ v.vid_id, v.vid_filename, v.folder_id_r, v.vid_custom_id, v.vid_extension, v.vid_online, v.vid_owner,
	v.vid_create_date, v.vid_create_time, v.vid_change_date, v.link_kind, v.link_path_url, v.cloud_url, v.cloud_url_org,
	v.vid_change_time, v.vid_mimetype, v.vid_publisher, v.vid_ranking rank, v.vid_single_sale, v.vid_is_new,
	v.vid_selection, v.vid_in_progress, v.vid_license, v.vid_name_org, v.vid_name_org filenameorg, v.shared, v.path_to_asset,
	v.vid_width vwidth, v.vid_height vheight, v.vid_size vlength, v.vid_name_image, v.vid_meta, v.hashtag,
	s.set2_img_download_org, s.set2_intranet_gen_download, s.set2_url_website, u.user_first_name, u.user_last_name,
	fo.folder_name, '' as perm
	FROM #session.hostdbprefix#videos v 
	LEFT JOIN #session.hostdbprefix#settings_2 s ON s.set2_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#application.razuna.setid#"> AND s.host_id = v.host_id
	LEFT JOIN users u ON u.user_id = v.vid_owner
	LEFT JOIN #session.hostdbprefix#folders fo ON fo.folder_id = v.folder_id_r AND fo.host_id = v.host_id
	WHERE v.vid_id = <cfqueryparam value="#arguments.thestruct.file_id#" cfsqltype="CF_SQL_VARCHAR">
	AND v.host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
	</cfquery>
	<!--- Get proper folderaccess --->
	<cfinvoke component="folders" method="setaccess" returnvariable="theaccess" folder_id="#details.folder_id_r#"  />
	<!--- Add labels query --->
	<cfset QuerySetCell(details, "perm", theaccess)>
	<!--- Get descriptions and keywords --->
	<cfquery datasource="#variables.dsn#" name="desc" cachedwithin="1" region="razcache">
	SELECT /* #variables.cachetoken#detaildescvid */ vid_description, vid_keywords, lang_id_r, vid_description as thedesc, vid_keywords as thekeys
	FROM #session.hostdbprefix#videos_text
	WHERE vid_id_r = <cfqueryparam value="#arguments.thestruct.file_id#" cfsqltype="CF_SQL_VARCHAR">
	</cfquery>
	<!--- Convert the size --->
	<cfif isnumeric(details.vlength)>
		<cfinvoke component="global" method="converttomb" returnvariable="thesize" thesize="#details.vlength#">
	<cfelse>
		<cfset thesize = 0>
	</cfif>
	<!--- Put into struct --->
	<cfset qry.detail = details>
	<cfset qry.desc = desc>
	<cfset qry.thesize = thesize>
	<!--- <cfset qry.theprevsize = theprevsize> --->
	<!--- Return --->
	<cfreturn qry>
</cffunction>

<!--- UPDATE VIDEOS IN THREAD --->
<cffunction name="update" output="false">
	<cfargument name="thestruct" type="struct">
	<!--- Set arguments --->
	<cfset arguments.thestruct.dsn = variables.dsn>
	<cfset arguments.thestruct.setid = variables.setid>
	<!--- Start the thread for updating --->
	<cfthread intstruct="#arguments.thestruct#">
		<cfinvoke method="updatethread" thestruct="#attributes.intstruct#" />
	</cfthread>
</cffunction>

<!--- SAVE THE VIDEO DETAILS --->
<cffunction name="updatethread" output="false">
	<cfargument name="thestruct" type="struct">
	<!--- Params --->
	<cfparam name="arguments.thestruct.shared" default="F">
	<cfparam name="arguments.thestruct.what" default="">
	<cfparam name="arguments.thestruct.vid_online" default="F">
	<cfparam name="arguments.thestruct.frombatch" default="F">
	<cfparam name="arguments.thestruct.batch_replace" default="true">
	<!--- Loop over the file_id (important when working on more then one image) --->
	<cfloop list="#arguments.thestruct.file_id#" delimiters="," index="i">
		<cfset var i = listfirst(i,"-")>
		<cfset arguments.thestruct.file_id = i>
		<!--- Save the desc and keywords --->
		<cfloop list="#arguments.thestruct.langcount#" index="langindex">
		<!--- If we come from all we need to change the desc and keywords arguments name --->
			<cfif arguments.thestruct.what EQ "all">
				<cfset var alldesc = "all_desc_#langindex#">
				<cfset var allkeywords = "all_keywords_#langindex#">
				<cfset var thisdesc = "arguments.thestruct.vid_desc_#langindex#">
				<cfset var thiskeywords = "arguments.thestruct.vid_keywords_#langindex#">
				<cfset "#thisdesc#" =  evaluate(alldesc)>
				<cfset "#thiskeywords#" =  evaluate(allkeywords)>
			<cfelse>
				<!--- <cfif langindex EQ 1>
					<cfset thisdesc = "desc_#langindex#">
					<cfset thiskeywords = "keywords_#langindex#">
				<cfelse> --->
					<cfset var thisdesc = "vid_desc_#langindex#">
					<cfset var thiskeywords = "vid_keywords_#langindex#">
				<!--- </cfif> --->
			</cfif>
			<cfset var l = langindex>
			<cfif thisdesc CONTAINS l OR thiskeywords CONTAINS l>
				<cfloop list="#arguments.thestruct.file_id#" delimiters="," index="f">
					<!--- Query excisting --->
					<cfquery datasource="#variables.dsn#" name="ishere">
					SELECT vid_id_r, vid_description, vid_keywords
					FROM #session.hostdbprefix#videos_text
					WHERE vid_id_r = <cfqueryparam value="#f#" cfsqltype="CF_SQL_VARCHAR">
					AND lang_id_r = <cfqueryparam value="#l#" cfsqltype="cf_sql_numeric">
					</cfquery>
					<cfif ishere.recordcount NEQ 0>
						<cfset tdesc = evaluate(thisdesc)>
						<cfset tkeywords = evaluate(thiskeywords)>
						<!--- If users chooses to append values --->
						<cfif !arguments.thestruct.batch_replace>
							<cfif ishere.vid_description NEQ "">
								<cfset tdesc = ishere.vid_description & " " & tdesc>
							</cfif>
							<cfif ishere.vid_keywords NEQ "">
								<cfset tkeywords = ishere.vid_keywords & "," & tkeywords>
							</cfif>
						</cfif>
						<!--- Update --->
						<cfquery datasource="#variables.dsn#">
						UPDATE #session.hostdbprefix#videos_text
						SET 
						vid_description = <cfqueryparam value="#ltrim(tdesc)#" cfsqltype="cf_sql_varchar">, 
						vid_keywords = <cfqueryparam value="#ltrim(tkeywords)#" cfsqltype="cf_sql_varchar">
						WHERE vid_id_r = <cfqueryparam value="#f#" cfsqltype="CF_SQL_VARCHAR">
						AND lang_id_r = <cfqueryparam value="#l#" cfsqltype="cf_sql_numeric">
						</cfquery>
					<cfelse>
						<cfquery datasource="#variables.dsn#">
						INSERT INTO #session.hostdbprefix#videos_text
						(id_inc, vid_id_r, lang_id_r, vid_description, vid_keywords, host_id)
						VALUES(
						<cfqueryparam value="#createuuid()#" cfsqltype="CF_SQL_VARCHAR">,
						<cfqueryparam value="#f#" cfsqltype="CF_SQL_VARCHAR">, 
						<cfqueryparam value="#l#" cfsqltype="cf_sql_numeric">, 
						<cfqueryparam value="#ltrim(evaluate(thisdesc))#" cfsqltype="cf_sql_varchar">, 
						<cfqueryparam value="#ltrim(evaluate(thiskeywords))#" cfsqltype="cf_sql_varchar">,
						<cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
						)
						</cfquery>
					</cfif>
				</cfloop>
			</cfif>
		</cfloop>
		<!--- Save to the files table --->
		<cfif structkeyexists(arguments.thestruct,"fname") AND arguments.thestruct.frombatch NEQ "T">
			<cfquery datasource="#variables.dsn#">
			UPDATE #session.hostdbprefix#videos
			SET
			vid_filename = <cfqueryparam value="#arguments.thestruct.fname#" cfsqltype="cf_sql_varchar">,
			vid_online = <cfqueryparam value="#arguments.thestruct.vid_online#" cfsqltype="cf_sql_varchar">,
			shared = <cfqueryparam value="#arguments.thestruct.shared#" cfsqltype="cf_sql_varchar">
			WHERE vid_id = <cfqueryparam value="#arguments.thestruct.file_id#" cfsqltype="CF_SQL_VARCHAR">
			AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
			</cfquery>
		</cfif>
		<!--- Update main record with dates --->
		<cfinvoke component="global" method="update_dates" type="vid" fileid="#arguments.thestruct.file_id#" />
		<!--- Query again --->
		<cfquery datasource="#variables.dsn#" name="qryorg">
		SELECT vid_name_org, vid_filename, path_to_asset
		FROM #session.hostdbprefix#videos
		WHERE vid_id = <cfqueryparam value="#arguments.thestruct.file_id#" cfsqltype="CF_SQL_VARCHAR">
		AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
		</cfquery>
		<!--- Select the record to get the original filename or assign if one is there --->
		<cfif NOT structkeyexists(arguments.thestruct,"filenameorg") OR arguments.thestruct.filenameorg EQ "">
			<cfset arguments.thestruct.qrydetail.filenameorg = qryorg.vid_name_org>
			<cfset arguments.thestruct.file_name = qryorg.vid_filename>
			<cfset arguments.thestruct.filenameorg = arguments.thestruct.qrydetail.filenameorg>
		<cfelse>
			<cfset arguments.thestruct.qrydetail.filenameorg = arguments.thestruct.filenameorg>
		</cfif>
		<!--- Lucene --->
		<cfset arguments.thestruct.qrydetail.folder_id_r = arguments.thestruct.folder_id>
		<cfset arguments.thestruct.qrydetail.path_to_asset = qryorg.path_to_asset>
		<!--- Local --->
		<cfif application.razuna.storage EQ "local">
			<!--- MD5 video --->
			<cfset consoleoutput(true)>
			<cfset console("#arguments.thestruct.assetpath#/#session.hostid#/#qryorg.path_to_asset#/#qryorg.vid_name_org#")>
			<cfif FileExists("#arguments.thestruct.assetpath#/#session.hostid#/#qryorg.path_to_asset#/#qryorg.vid_name_org#")>
				<cfset var md5hash = hashbinary("#arguments.thestruct.assetpath#/#session.hostid#/#qryorg.path_to_asset#/#qryorg.vid_name_org#")>
				<!--- Update DB --->
				<cfquery datasource="#variables.dsn#">
				UPDATE #session.hostdbprefix#videos
				SET hashtag = <cfqueryparam value="#md5hash#" cfsqltype="cf_sql_varchar">
				WHERE vid_id = <cfqueryparam value="#arguments.thestruct.file_id#" cfsqltype="CF_SQL_VARCHAR">
				AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
				</cfquery>
			</cfif>
			<cfinvoke component="lucene" method="index_delete" thestruct="#arguments.thestruct#" assetid="#arguments.thestruct.file_id#" category="vid">
			<cfinvoke component="lucene" method="index_update" dsn="#variables.dsn#" prefix="#session.hostdbprefix#" thestruct="#arguments.thestruct#" assetid="#arguments.thestruct.file_id#" category="vid">
		<!--- Nirvanix --->
		<cfelseif application.razuna.storage NEQ "local">
			<cfinvoke component="lucene" method="index_delete" thestruct="#arguments.thestruct#" assetid="#arguments.thestruct.file_id#" category="vid" notfile="T">
			<cfinvoke component="lucene" method="index_update" dsn="#variables.dsn#" prefix="#session.hostdbprefix#" thestruct="#arguments.thestruct#" assetid="#arguments.thestruct.file_id#" category="vid" notfile="T">
		</cfif>
		<!--- Log --->
		<cfset log_assets(theuserid=session.theuserid,logaction='Update',logdesc='Updated: #qryorg.vid_filename#',logfiletype='vid',assetid='#arguments.thestruct.file_id#')>
	</cfloop>
	<!--- Flush Cache --->
	<cfset variables.cachetoken = resetcachetoken("videos")>
	<cfset resetcachetoken("folders")>
	<cfset resetcachetoken("search")> 
</cffunction>

<!--- CONVERT VIDEO IN A THREAD --->
<cffunction name="convertvideothread" output="true">
	<cfargument name="thestruct" type="struct">
	<!--- RFS --->
	<cfif application.razuna.rfs>
		<cfset arguments.thestruct.convert = true>
		<cfset arguments.thestruct.assettype = "vid">
		<cfthread intstruct="#arguments.thestruct#">
			<cfinvoke component="rfs" method="notify" thestruct="#attributes.intstruct#" />
		</cfthread>
	<cfelse>
		<cfthread intstruct="#arguments.thestruct#">
			<cfinvoke method="convertvideo" thestruct="#attributes.intstruct#" />
		</cfthread>
	</cfif>
</cffunction>

<!--- CONVERT VIDEO --->
<cffunction name="convertvideo" output="true">
	<cfargument name="thestruct" type="struct">
	<cftry>
		<!--- Param --->
		<cfset arguments.thestruct.qrydetail = "">
		<cfset arguments.thestruct.dsn = application.razuna.datasource>
		<cfset arguments.thestruct.setid = application.razuna.setid>
		<cfset arguments.thestruct.hostid = session.hostid>
		<cfparam name="fromadmin" default="F">
		<cfset var cloud_url = structnew()>
		<cfset var cloud_url_org = structnew()>
		<cfset var cloud_url_2 = structnew()>
		<cfset var qry_detail = "">
		<cfset cloud_url_org.theurl = "">
		<cfset cloud_url.theurl = "">
		<cfset cloud_url_2.theurl = "">
		<cfset cloud_url_org.newepoch = 0>
		<cfparam name="arguments.thestruct.upl_template" default="0">
		<!--- Go grab the platform --->
		<cfinvoke component="assets" method="iswindows" returnvariable="iswindows">
		<!--- Get Tools --->
		<cfinvoke component="settings" method="get_tools" returnVariable="arguments.thestruct.thetools" />
		<!--- Get details --->
		<cfinvoke method="getdetails" vid_id="#arguments.thestruct.file_id#" returnvariable="qry_detail">
		<!--- Update main record with dates --->
		<cfinvoke component="global" method="update_dates" type="vid" fileid="#qry_detail.vid_group#" />
		<!--- Create a temp directory to hold the video file (needed because we are doing other files from it as well) --->
		<cfset var tempfolder = "vid#createuuid('')#">
		<!--- set the folder path in a var --->
		<cfset var thisfolder = "#arguments.thestruct.thepath#/incoming/#tempfolder#">
		<!--- Create the temp folder in the incoming dir --->
		<cfdirectory action="create" directory="#thisfolder#" mode="775">
		<!--- Create uuid for thread --->
		<cfset var tt = createuuid("")>
		<cfset arguments.thestruct.qrydetail = qry_detail>
		<cfset arguments.thestruct.this_folder = thisfolder>
		<!--- Now get the extension and the name after the position from above --->
		<cfset var thenamenoext = listfirst(arguments.thestruct.qrydetail.vid_name_org, ".")>
		<cfset var thename = arguments.thestruct.qrydetail.vid_name_org>
		<cfset arguments.thestruct.thename = thename>
		<!--- Local --->
		<cfif application.razuna.storage EQ "local">
			<!--- Set the input path --->
			<cfset var inputpath = "#arguments.thestruct.assetpath#/#session.hostid#/#arguments.thestruct.qrydetail.path_to_asset#/#arguments.thestruct.qrydetail.vid_name_org#">
			<!--- Set the input path for the still image --->
			<cfset var inputpathimage = "#arguments.thestruct.assetpath#/#session.hostid#/#arguments.thestruct.qrydetail.path_to_asset#/#arguments.thestruct.qrydetail.vid_name_image#">
			<cfthread name="convert#tt#" intstruct="#arguments.thestruct#" />
		<!--- Nirvanix --->
		<cfelseif application.razuna.storage EQ "nirvanix">
			<!--- Download file --->
			<cfthread name="download#tt#" intstruct="#arguments.thestruct#">
				<cfhttp url="#attributes.intstruct.qrydetail.cloud_url_org#" file="#attributes.intstruct.qrydetail.vid_name_org#" path="#attributes.intstruct.this_folder#"></cfhttp>
				<cfhttp url="#attributes.intstruct.qrydetail.cloud_url#" file="#attributes.intstruct.qrydetail.vid_name_image#" path="#attributes.intstruct.this_folder#"></cfhttp>
			</cfthread>
			<!--- Wait for the thread above until the file is downloaded fully --->
			<cfthread action="join" name="download#tt#" />
			<!--- Wait for the thread above until the file is downloaded fully --->
			<cfthread name="convert#tt#" />
			<!--- Set the input path --->
			<cfset var inputpath = "#thisfolder#/#thename#">
			<!--- Set the input path for the still image --->
			<cfset var inputpathimage = "#thisfolder#/#arguments.thestruct.qrydetail.vid_name_image#">
		<!--- Amazon --->
		<cfelseif application.razuna.storage EQ "amazon">
			<!--- Download file --->
			<cfthread name="download#tt#" intstruct="#arguments.thestruct#">
				<!--- Download video --->
				<cfinvoke component="amazon" method="Download">
					<cfinvokeargument name="key" value="/#attributes.intstruct.qrydetail.path_to_asset#/#attributes.intstruct.qrydetail.vid_name_org#">
					<cfinvokeargument name="theasset" value="#attributes.intstruct.this_folder#/#attributes.intstruct.thename#">
					<cfinvokeargument name="awsbucket" value="#attributes.intstruct.awsbucket#">
				</cfinvoke>
				<!--- Download still images --->
				<cfinvoke component="amazon" method="Download">
					<cfinvokeargument name="key" value="/#attributes.intstruct.qrydetail.path_to_asset#/#attributes.intstruct.qrydetail.vid_name_image#">
					<cfinvokeargument name="theasset" value="#attributes.intstruct.this_folder#/#attributes.intstruct.qrydetail.vid_name_image#">
					<cfinvokeargument name="awsbucket" value="#attributes.intstruct.awsbucket#">
				</cfinvoke>
			</cfthread>
			<!--- Wait for the thread above until the file is downloaded fully --->
			<cfthread action="join" name="download#tt#" />
			<cfthread name="convert#tt#" />
			<!--- Set the input path --->
			<cfset var inputpath = "#thisfolder#/#thename#">
			<!--- Set the input path for the still image --->
			<cfset var inputpathimage = "#thisfolder#/#arguments.thestruct.qrydetail.vid_name_image#">
		<!--- Akamai --->
		<cfelseif application.razuna.storage EQ "akamai">
			<!--- Download file --->
			<cfthread name="download#tt#" intstruct="#arguments.thestruct#">
				<!--- Download video --->
				<cfhttp url="#attributes.intstruct.akaurl##attributes.intstruct.akavid#/#attributes.intstruct.qrydetail.vid_name_org#" file="#attributes.intstruct.qrydetail.vid_name_org#" path="#attributes.intstruct.this_folder#"></cfhttp>
				<!--- Download still images --->
				
			</cfthread>
			<!--- Wait for the thread above until the file is downloaded fully --->
			<cfthread action="join" name="download#tt#" />
			<cfthread name="convert#tt#" />
			<!--- Set the input path --->
			<cfset var inputpath = "#thisfolder#/#thename#">
			<!--- Set the input path for the still image --->
			<cfset var inputpathimage = "#thisfolder#/#arguments.thestruct.qrydetail.vid_name_image#">
		</cfif>
		<!--- Wait for the thread above until the file is downloaded fully --->
		<cfthread action="join" name="convert#tt#" />
		<!--- On local link asset we have a different input path --->
		<cfif arguments.thestruct.link_kind EQ "lan">
			<cfset var inputpath = "#arguments.thestruct.link_path_url#">
		</cfif>
		<!--- Check the platform and then decide on the ffmpeg tag --->
		<cfif isWindows>
			<cfset var theexe = """#arguments.thestruct.thetools.ffmpeg#/ffmpeg.exe""">
			<cfset var theimexe = """#arguments.thestruct.thetools.imagemagick#/convert.exe""">
			<cfset var inputpath = """#inputpath#""">
			<cfset var inputpathimage = """#inputpathimage#""">
			<cfset var themp4 = "#arguments.thestruct.thetools.mp4box#/MP4Box.exe">
		<cfelse>
			<cfset var theexe = "#arguments.thestruct.thetools.ffmpeg#/ffmpeg">
			<cfset var theimexe = "#arguments.thestruct.thetools.imagemagick#/convert">
			<cfset var themp4 = "#arguments.thestruct.thetools.mp4box#/MP4Box">
		</cfif>
		<!--- Now, loop over the selected extensions and convert and store video --->
		<cfloop delimiters="," list="#arguments.thestruct.convert_to#" index="theformat">
			<!--- create new id --->
			<cfset arguments.thestruct.newid = createuuid("")>
			<!--- Insert record --->
			<cfquery datasource="#application.razuna.datasource#">
			INSERT INTO #session.hostdbprefix#videos
			(vid_id, host_id)
			VALUES( 
			<cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#arguments.thestruct.newid#">,
			<cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#"> 
			)
			</cfquery>
			<!--- If from upload templates we select with and height of image --->
			<cfif arguments.thestruct.upl_template NEQ 0 AND arguments.thestruct.upl_template NEQ "undefined" AND arguments.thestruct.upl_template NEQ "">
				<cfquery datasource="#application.razuna.datasource#" name="qry_w">
				SELECT upl_temp_field, upl_temp_value
				FROM #session.hostdbprefix#upload_templates_val
				WHERE upl_temp_field = <cfqueryparam CFSQLType="CF_SQL_VARCHAR" value="convert_width_#theformat#">
				AND upl_temp_id_r = <cfqueryparam CFSQLType="CF_SQL_VARCHAR" value="#arguments.thestruct.upl_template#">
				AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#arguments.thestruct.hostid#">
				</cfquery>
				<cfquery datasource="#application.razuna.datasource#" name="qry_h">
				SELECT upl_temp_field, upl_temp_value
				FROM #session.hostdbprefix#upload_templates_val
				WHERE upl_temp_field = <cfqueryparam CFSQLType="CF_SQL_VARCHAR" value="convert_height_#theformat#">
				AND upl_temp_id_r = <cfqueryparam CFSQLType="CF_SQL_VARCHAR" value="#arguments.thestruct.upl_template#">
				AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#arguments.thestruct.hostid#">
				</cfquery>
				<cfquery datasource="#application.razuna.datasource#" name="qry_b">
				SELECT upl_temp_field, upl_temp_value
				FROM #session.hostdbprefix#upload_templates_val
				WHERE upl_temp_field = <cfqueryparam CFSQLType="CF_SQL_VARCHAR" value="convert_bitrate_#theformat#">
				AND upl_temp_id_r = <cfqueryparam CFSQLType="CF_SQL_VARCHAR" value="#arguments.thestruct.upl_template#">
				AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#arguments.thestruct.hostid#">
				</cfquery>
				<!--- Set image width and height --->
				<cfset var thewidth  = qry_w.upl_temp_value>
				<cfset var theheight = qry_h.upl_temp_value>
				<!--- <cfset thebitrate = qry_b.upl_temp_value>  --->
				<!--- If height and size is empty we take the default values from the original file --->
				<cfif NOT isnumeric(thewidth) AND NOT isnumeric(theheight)>
					<cfset var thewidth  = arguments.thestruct.qrydetail.vwidth>
					<cfset var theheight = arguments.thestruct.qrydetail.vheight>
				</cfif>
				<!--- If bitrate is empty
				<cfif thebitrate EQ "">
					<cfset thebitrate = "600">
				</cfif> --->
			<cfelse>		
				<!--- <cfset thebitrate = Evaluate("arguments.thestruct.convert_bitrate_#theformat#")>
				<cfif thebitrate EQ ""><cfset thebitrate = "600"></cfif> --->
				<cfset var thewidth = Evaluate("arguments.thestruct.convert_width_#theformat#")>
				<cfset var theheight = Evaluate("arguments.thestruct.convert_height_#theformat#")>
			</cfif>
			<!--- From here on we need to remove the number of the format (if any) --->
			<cfset var theformat = listfirst(theformat,"_")>
			<!--- Put together the filenames --->
			<cfset var newname = listfirst(arguments.thestruct.qrydetail.vid_name_org, ".")>
			<cfset var previewvideo = "#newname#" & "_" & arguments.thestruct.newid & "." & theformat>
			<cfset var previewimage = "#newname#" & "_" & arguments.thestruct.newid & ".jpg">
			<!--- Change path according to OS --->
			<cfif isWindows>
				<cfset var thispreviewvideo = """#thisfolder#/#previewvideo#""">
				<cfset var thispreviewimage = """#thisfolder#/#previewimage#""">
			<cfelse>
				<cfset var thispreviewvideo = "#thisfolder#/#previewvideo#">
				<cfset var thispreviewimage = "#thisfolder#/#previewimage#">
			</cfif>
			<!--- FFMPEG: Convert video to selected format --->
			<cfswitch expression="#theformat#">
				<!--- if AVI --->
				<cfcase value="avi">
					<cfset var theargument="-i #inputpath# -s #thewidth#x#theheight# -vcodec libx264 -pix_fmt yuv420p  -ac 2 -y #thispreviewvideo#">
				</cfcase>
				<!--- if 3GP --->
				<cfcase value="3gp">
					<!--- If we convert a VOB file then --->
					<cfif arguments.thestruct.qrydetail.vid_extension EQ "vob">
						<cfif isWindows>
							<cfset var theacodec = "libvo_aacenc">
						<cfelse>
							<cfset var theacodec = "libfaac">
						</cfif>
					<cfelse>
						<cfset var theacodec = "copy">
					</cfif>
					<cfset var theargument="-i #inputpath# -vcodec h263 -acodec #theacodec# -ac 1 -ar 8000 -r 25 -ab 12.2k -s #thewidth#x#theheight# -y #thispreviewvideo#">
				</cfcase>
				<!--- MXF --->
				<cfcase value="mxf">
					<cfset var theargument="-i #inputpath# -s #thewidth#x#theheight# -acodec pcm_s16le -ar 48000 -ac 2 -vsync 2 -y #thispreviewvideo#">
				</cfcase>
				<!--- WMV --->
				<cfcase value="wmv">
					<cfset var theargument="-i #inputpath# -s #thewidth#x#theheight# -vcodec wmv2 -acodec wmav2 -ar 48000 -ab 400k -ac 2 -vsync 2 -y #thispreviewvideo#">
				</cfcase>
				<!--- OGV --->
				<cfcase value="ogv">
					<cfset var theargument="-i #inputpath# -s #thewidth#x#theheight# -crf 22 -threads 2 -acodec libvorbis -vsync 2 -y #thispreviewvideo#">
				</cfcase>
				<!--- WebM --->
				<cfcase value="webm">
					<!--- <cfset bitrate = thebitrate * 1024> --->
					<cfset var theargument="-i #inputpath# -s #thewidth#x#theheight# -crf 22 -threads 2 -vcodec libvpx -acodec libvorbis -y #thispreviewvideo#">
				</cfcase>
				<cfdefaultcase>
					<cfif isWindows>
						<cfset var theaac = "libvo_aacenc">
					<cfelse>
						<cfset var theaac = "libfaac">
					</cfif>

					<cfset var theargument="-i #inputpath# -s #thewidth#x#theheight# -vcodec libx264 -pix_fmt yuv420p -acodec #theaac# -crf 22 -threads 2 -y #thispreviewvideo#">
				</cfdefaultcase>
			</cfswitch>
			<!--- FFMPEG: CONVERT THE VIDEO --->
			<cfset arguments.thestruct.theargument = theargument>
			<cfset arguments.thestruct.theexe = theexe>
			<cfset var thescript = arguments.thestruct.newid>
			<cfset arguments.thestruct.thesh = GetTempDirectory() & "/#thescript#.sh">
			<!--- On Windows a bat --->
			<cfif isWindows>
				<cfset arguments.thestruct.thesh = GetTempDirectory() & "/#thescript#.bat">
			</cfif>
			<!--- Write files --->
			<cffile action="write" file="#arguments.thestruct.thesh#" output="#arguments.thestruct.theexe# #arguments.thestruct.theargument#" mode="777">
			<!--- Convert video --->
			<cfset var ttexe = createuuid("")>
			<cfthread name="#ttexe#" intstruct="#arguments.thestruct#">
				<cfexecute name="#attributes.intstruct.thesh#" timeout="24000" />
			</cfthread>
			<!--- Wait for the thread above until the file is fully converted --->
			<cfthread action="join" name="#ttexe#" />
			<!--- Delete scripts --->
			<cffile action="delete" file="#arguments.thestruct.thesh#">
			<!--- Check if video file could be generated by getting the size --->
			<cfinvoke component="global" method="getfilesize" filepath="#thisfolder#/#previewvideo#" returnvariable="siz">
			<cfif siz EQ 0>
				<cfquery datasource="#application.razuna.datasource#" name="qryuser">
				SELECT user_email
				FROM users
				WHERE user_id = <cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#session.theuserid#">
				</cfquery>
				<cfinvoke component="email" method="send_email" prefix="#session.hostdbprefix#" to="#qryuser.user_email#" subject="Error on converting your video" themessage="Your Video could not be converted to the format #ucase(theformat)#. This can happen when the source video is rendered with codecs that our conversion engine can not read/write.">
			<cfelse>
				<!--- If we are MP4 run it trough MP4Box --->
				<cfif theformat EQ "mp4" AND arguments.thestruct.thetools.mp4box NEQ "">
					<cfset var ttmp4 = createuuid("")>
					<cfset arguments.thestruct.thispreviewvideo = thispreviewvideo>
					<cfset arguments.thestruct.themp4 = themp4>
					<cfthread name="#ttmp4#" intstruct="#arguments.thestruct#">
						<cfexecute name="#attributes.intstruct.themp4#" arguments="-inter 500 #attributes.intstruct.thispreviewvideo#" timeout="9999" />
					</cfthread>
					<!--- Wait for the thread above until the file is fully converted --->
					<cfthread action="join" name="#ttmp4#" />
				</cfif>
				<!--- Get size of original --->
				<cfinvoke component="global" method="getfilesize" filepath="#thisfolder#/#previewvideo#" returnvariable="orgsize">
				<!--- MD5 Hash --->
				<cfif FileExists("#thisfolder#/#previewvideo#")>
					<cfset var md5hash = hashbinary("#thisfolder#/#previewvideo#")>
				</cfif>
				<!--- Storage: Local --->
				<cfif application.razuna.storage EQ "local">
					<!--- IMAGEMAGICK: copy over the existing still image and resize --->
					<cfexecute name="#theimexe#" arguments="#inputpathimage# -resize #thewidth#x#theheight# #thispreviewimage#" timeout="5" />
					<!--- Now move the files to its own folder --->
					<!--- Create folder first --->
					<cfdirectory action="create" directory="#arguments.thestruct.assetpath#/#session.hostid#/#arguments.thestruct.qrydetail.folder_id_r#/vid/#arguments.thestruct.newid#" mode="775">
					<!--- Move video --->
					<cffile action="move" source="#thisfolder#/#previewvideo#" destination="#arguments.thestruct.assetpath#/#session.hostid#/#arguments.thestruct.qrydetail.folder_id_r#/vid/#arguments.thestruct.newid#" mode="775">
					<!--- Move still image --->
					<cffile action="move" source="#thisfolder#/#previewimage#" destination="#arguments.thestruct.assetpath#/#session.hostid#/#arguments.thestruct.qrydetail.folder_id_r#/vid/#arguments.thestruct.newid#" mode="775">
					<cfthread name="uploadconvert#ttexe##theformat#" intstruct="#arguments.thestruct#"></cfthread>
				<!--- Nirvanix --->
				<cfelseif application.razuna.storage EQ "nirvanix">
					<!--- Set params for thread --->
					<cfset arguments.thestruct.thispreviewimage = thispreviewimage>
					<cfset arguments.thestruct.previewimage = previewimage>
					<cfset arguments.thestruct.previewvideo = previewvideo>
					<!--- IMAGEMAGICK: copy over the existing still image and resize --->
					<cfexecute name="#theimexe#" arguments="#inputpathimage# -resize #thewidth#x#theheight# #thispreviewimage#" timeout="5" />
					<!--- Copy the video image --->
					<cfthread name="uploadconvertc#ttexe##theformat#" intstruct="#arguments.thestruct#">
						<cfinvoke component="nirvanix" method="Upload">
							<cfinvokeargument name="destFolderPath" value="/#attributes.intstruct.qrydetail.folder_id_r#/vid/#attributes.intstruct.newid#">
							<cfinvokeargument name="uploadfile" value="#attributes.intstruct.thispreviewimage#">
							<cfinvokeargument name="nvxsession" value="#attributes.intstruct.nvxsession#">
						</cfinvoke>
					</cfthread>
					<!--- Wait for this thread to finish --->
					<cfthread action="join" name="uploadconvertc#ttexe##theformat#" />
					<!--- Upload: Video --->
					<cfthread name="uploadconvertu#ttexe##theformat#" intstruct="#arguments.thestruct#">
						<cfinvoke component="nirvanix" method="Upload">
							<cfinvokeargument name="destFolderPath" value="/#attributes.intstruct.qrydetail.folder_id_r#/vid/#attributes.intstruct.newid#">
							<cfinvokeargument name="uploadfile" value="#attributes.intstruct.this_folder#/#attributes.intstruct.previewvideo#">
							<cfinvokeargument name="nvxsession" value="#attributes.intstruct.nvxsession#">
						</cfinvoke>
					</cfthread>
					<!--- Wait for this thread to finish --->
					<cfthread action="join" name="uploadconvertu#ttexe##theformat#" />
					<!--- Get signed URLS --->
					<cfinvoke component="nirvanix" method="signedurl" returnVariable="cloud_url" theasset="#arguments.thestruct.qrydetail.folder_id_r#/vid/#arguments.thestruct.newid#/#arguments.thestruct.previewimage#" nvxsession="#arguments.thestruct.nvxsession#">
					<!--- Get signed URLS --->
					<cfinvoke component="nirvanix" method="signedurl" returnVariable="cloud_url_org" theasset="#arguments.thestruct.qrydetail.folder_id_r#/vid/#arguments.thestruct.newid#/#arguments.thestruct.previewvideo#" nvxsession="#arguments.thestruct.nvxsession#">
				<!--- Amazon --->
				<cfelseif application.razuna.storage EQ "amazon">
					<!--- Set params for thread --->
					<cfset arguments.thestruct.thispreviewimage = thispreviewimage>
					<cfset arguments.thestruct.previewimage = previewimage>
					<cfset arguments.thestruct.previewvideo = previewvideo>
					<!--- IMAGEMAGICK: copy over the existing still image and resize --->
					<cfexecute name="#theimexe#" arguments="#inputpathimage# -resize #thewidth#x#theheight# #thispreviewimage#" timeout="5" />
					<!--- Upload --->
					<cfthread name="uploadconvert#ttexe##theformat#" intstruct="#arguments.thestruct#">
						<!--- Upload: Video --->
						<cfinvoke component="amazon" method="Upload">
							<cfinvokeargument name="key" value="/#attributes.intstruct.qrydetail.folder_id_r#/vid/#attributes.intstruct.newid#/#attributes.intstruct.previewvideo#">
							<cfinvokeargument name="theasset" value="#attributes.intstruct.this_folder#/#attributes.intstruct.previewvideo#">
							<cfinvokeargument name="awsbucket" value="#attributes.intstruct.awsbucket#">
						</cfinvoke>
						<!--- Upload: Still Image --->
						<cfinvoke component="amazon" method="Upload">
							<cfinvokeargument name="key" value="/#attributes.intstruct.qrydetail.folder_id_r#/vid/#attributes.intstruct.newid#/#attributes.intstruct.thispreviewimage#">
							<cfinvokeargument name="theasset" value="#attributes.intstruct.this_folder#/#attributes.intstruct.previewimage#">
							<cfinvokeargument name="awsbucket" value="#attributes.intstruct.awsbucket#">
						</cfinvoke>
					</cfthread>
					<!--- Wait for this thread to finish --->
					<cfthread action="join" name="uploadconvert#ttexe##theformat#" />
					<!--- Get signed URLS --->
					<cfinvoke component="amazon" method="signedurl" returnVariable="cloud_url" key="#arguments.thestruct.qrydetail.folder_id_r#/vid/#arguments.thestruct.newid#/#arguments.thestruct.previewimage#" awsbucket="#arguments.thestruct.awsbucket#">
					<!--- Get signed URLS --->
					<cfinvoke component="amazon" method="signedurl" returnVariable="cloud_url_org" key="#arguments.thestruct.qrydetail.folder_id_r#/vid/#arguments.thestruct.newid#/#arguments.thestruct.previewvideo#" awsbucket="#arguments.thestruct.awsbucket#">
				<!--- Akamai --->
				<cfelseif application.razuna.storage EQ "akamai">
					<!--- Set params for thread --->
					<cfset arguments.thestruct.thispreviewimage = thispreviewimage>
					<cfset arguments.thestruct.previewimage = previewimage>
					<cfset arguments.thestruct.previewvideo = previewvideo>
					<!--- IMAGEMAGICK: copy over the existing still image and resize --->
					<cfexecute name="#theimexe#" arguments="#inputpathimage# -resize #thewidth#x#theheight# #thispreviewimage#" timeout="5" />
					<!--- Upload --->
					<cfthread name="uploadconvert#ttexe##theformat#" intstruct="#arguments.thestruct#">
						<!--- Upload: Video --->
						<cfinvoke component="akamai" method="Upload">
							<cfinvokeargument name="theasset" value="#attributes.intstruct.this_folder#/#attributes.intstruct.previewvideo#">
							<cfinvokeargument name="thetype" value="#attributes.intstruct.akavid#">
							<cfinvokeargument name="theurl" value="#attributes.intstruct.akaurl#">
							<cfinvokeargument name="thefilename" value="#attributes.intstruct.previewvideo#">
						</cfinvoke>
						<!--- Upload: Still Image --->
						<!--- <cfinvoke component="amazon" method="Upload">
							<cfinvokeargument name="key" value="/#attributes.intstruct.qrydetail.folder_id_r#/vid/#attributes.intstruct.newid#/#attributes.intstruct.thispreviewimage#">
							<cfinvokeargument name="theasset" value="#attributes.intstruct.this_folder#/#attributes.intstruct.previewimage#">
							<cfinvokeargument name="awsbucket" value="#attributes.intstruct.awsbucket#">
						</cfinvoke> --->
					</cfthread>
					<!--- Wait for this thread to finish --->
					<cfthread action="join" name="uploadconvert#ttexe##theformat#" />
				</cfif>
				<!--- Add to shared options --->
				<cftransaction>
					<cfquery datasource="#application.razuna.datasource#">
					INSERT INTO #session.hostdbprefix#share_options
					(asset_id_r, host_id, group_asset_id, folder_id_r, asset_type, asset_format, asset_dl, asset_order, rec_uuid)
					VALUES(
					<cfqueryparam value="#arguments.thestruct.newid#" cfsqltype="CF_SQL_VARCHAR">,
					<cfqueryparam value="#session.hostid#" cfsqltype="cf_sql_numeric">,
					<cfqueryparam value="#arguments.thestruct.file_id#" cfsqltype="CF_SQL_VARCHAR">,
					<cfqueryparam value="#arguments.thestruct.qrydetail.folder_id_r#" cfsqltype="CF_SQL_VARCHAR">,
					<cfqueryparam value="vid" cfsqltype="cf_sql_varchar">,
					<cfqueryparam value="#arguments.thestruct.newid#" cfsqltype="cf_sql_varchar">,
					<cfqueryparam value="1" cfsqltype="cf_sql_varchar">,
					<cfqueryparam value="1" cfsqltype="cf_sql_varchar">,
					<cfqueryparam value="#createuuid()#" CFSQLType="CF_SQL_VARCHAR">
					)
					</cfquery>
					<!--- Update the video record with other information --->
					<cfquery datasource="#application.razuna.datasource#">
					UPDATE #session.hostdbprefix#videos
					SET 
					vid_group = <cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#arguments.thestruct.file_id#">,
					vid_filename = <cfqueryparam cfsqltype="cf_sql_varchar" value="#previewvideo#">,
					vid_custom_id = <cfqueryparam cfsqltype="cf_sql_varchar" value="#arguments.thestruct.newid#">,
					vid_owner = <cfqueryparam value="#session.theuserid#" cfsqltype="CF_SQL_VARCHAR">,
					vid_create_date = <cfqueryparam cfsqltype="cf_sql_date" value="#now()#">,
					vid_change_date = <cfqueryparam cfsqltype="cf_sql_date" value="#now()#">,
					vid_create_time = <cfqueryparam cfsqltype="cf_sql_timestamp" value="#now()#">,
					vid_change_time = <cfqueryparam cfsqltype="cf_sql_timestamp" value="#now()#">,
					vid_extension = <cfqueryparam value="#theformat#" cfsqltype="cf_sql_varchar">,
					<!--- vid_preview_width = <cfqueryparam cfsqltype="cf_sql_numeric" value="#thewidth#">, --->
					<!--- vid_preview_heigth = <cfqueryparam cfsqltype="cf_sql_numeric" value="#theheight#">, --->
					vid_width = <cfqueryparam cfsqltype="cf_sql_numeric" value="#thewidth#">,
					vid_height = <cfqueryparam cfsqltype="cf_sql_numeric" value="#theheight#">,
					vid_name_org = <cfqueryparam cfsqltype="cf_sql_varchar" value="#previewvideo#">,
					vid_name_image  = <cfqueryparam cfsqltype="cf_sql_varchar" value="#previewimage#">,
					<!--- vid_name_pre = <cfqueryparam cfsqltype="cf_sql_varchar" value="#previewvideo#">, --->
					<!--- vid_name_pre_img  = <cfqueryparam cfsqltype="cf_sql_varchar" value="#previewimage#">, --->
					folder_id_r = <cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#arguments.thestruct.qrydetail.folder_id_r#">,
				 	vid_size = <cfqueryparam cfsqltype="cf_sql_numeric" value="#orgsize#">,
				 	vid_prev_size = <cfqueryparam cfsqltype="cf_sql_numeric" value="#orgsize#">,
				 	path_to_asset = <cfqueryparam cfsqltype="cf_sql_varchar" value="#arguments.thestruct.qrydetail.folder_id_r#/vid/#arguments.thestruct.newid#">,
				 	cloud_url = <cfqueryparam value="#cloud_url.theurl#" cfsqltype="cf_sql_varchar">,
				 	cloud_url_org = <cfqueryparam value="#cloud_url_org.theurl#" cfsqltype="cf_sql_varchar">,
					cloud_url_exp = <cfqueryparam value="#cloud_url_org.newepoch#" cfsqltype="CF_SQL_NUMERIC">,
					is_available = <cfqueryparam value="1" cfsqltype="cf_sql_varchar">,
					hashtag = <cfqueryparam value="#md5hash#" cfsqltype="cf_sql_varchar">
					WHERE vid_id = <cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#arguments.thestruct.newid#">
					AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
					</cfquery>
				</cftransaction>
				<!--- Log --->
				<cfset log_assets(theuserid=session.theuserid,logaction='Convert',logdesc='Converted: #arguments.thestruct.qrydetail.vid_name_org# to #previewvideo# (#thewidth#x#theheight#)',logfiletype='vid',assetid='#arguments.thestruct.file_id#')>
				<!--- Call Plugins --->
				<cfset arguments.thestruct.fileid = arguments.thestruct.newid>
				<cfset arguments.thestruct.file_name = previewvideo>
				<cfset arguments.thestruct.folder_id = arguments.thestruct.qrydetail.folder_id_r>
				<cfset arguments.thestruct.thefiletype = "vid">
				<cfset arguments.thestruct.folder_action = false>
				<!--- Check on any plugin that call the on_rendition_add action --->
				<cfinvoke component="plugins" method="getactions" theaction="on_rendition_add" args="#arguments.thestruct#" />
			</cfif>
		</cfloop>
		<!--- Flush Cache --->
		<cfset resetcachetoken("search")>
		<cfset variables.cachetoken = resetcachetoken("videos")>
		<cfcatch type="any">
			<cfmail to="support@razuna.com" from="server@razuna.com" subject="Error on convert video" type="html">
				<cfdump var="#cfcatch#">
				<cfdump var="#arguments.thestruct#">
			</cfmail>
		</cfcatch>
	</cftry>
</cffunction>

<!--- WRITE VIDEO TO SYSTEM --->
<cffunction name="writevideo" output="true">
	<cfargument name="thestruct" type="struct">
	<cfparam name="arguments.thestruct.zipit" default="T">
	<!--- Create a temp folder --->
	<cfset tempfolder = createuuid("")>
	<cfdirectory action="create" directory="#arguments.thestruct.thepath#/outgoing/#tempfolder#" mode="775">
	<!--- The tool paths --->
	<cfinvoke component="settings" method="get_tools" returnVariable="arguments.thestruct.thetools" />
	<!--- Go grab the platform --->
	<cfinvoke component="assets" method="iswindows" returnvariable="arguments.thestruct.iswindows">
	<!--- Put the video id into a variable --->
	<cfset thevideoid = #arguments.thestruct.file_id#>
	<!--- Start the loop to get the different kinds of videos --->
	<cfloop delimiters="," list="#session.artofimage#" index="art">
		<!--- Since the video format could be from the related table we need to check this here so if the value is a number it is the id for the video --->
		<cfif isnumeric(art)>
			<!--- Set the video id for this type of format and set the extension --->
			<cfset thevideoid = #art#>
			<cfquery name="ext" datasource="#variables.dsn#">
			SELECT vid_extension
			FROM #session.hostdbprefix#videos
			WHERE vid_id = <cfqueryparam value="#thevideoid#" cfsqltype="CF_SQL_VARCHAR">
			AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
			</cfquery>
			<cfset art = #ext.vid_extension#>
		</cfif>
		<!--- check the create zip --->
		<cfif session.createzip EQ 'no'>
			<!--- Create subfolder with image name --->
			<cfdirectory action="create" directory="#arguments.thestruct.thepath#/outgoing/#tempfolder#/#arguments.thestruct.zipname#" mode="775">
		<cfelse>
			<!--- Create subfolder for the kind of video --->
			<cfdirectory action="create" directory="#arguments.thestruct.thepath#/outgoing/#tempfolder#/#art#" mode="775">
		</cfif>
		<!--- Set the colname to get from oracle to video_preview else to video always --->
		<cfif #art# EQ "video_preview">
			<cfset thecolname = "video_preview">
		<cfelse>
			<cfset thecolname = "video">
		</cfif>
		<!--- Query the db --->
		<cfquery name="qry" datasource="#variables.dsn#">
		SELECT v.vid_mimetype mt, v.vid_filename, v.vid_extension, v.vid_name_pre, v.vid_name_org, v.folder_id_r,
		v.vid_group, s.set2_url_sp_#thecolname# urloracle, v.link_kind, v.link_path_url, v.path_to_asset, cloud_url, cloud_url_org
		FROM #session.hostdbprefix#videos v, #session.hostdbprefix#settings_2 s
		WHERE v.vid_id = <cfqueryparam value="#thevideoid#" cfsqltype="CF_SQL_VARCHAR">
		AND s.set2_id = <cfqueryparam value="#variables.setid#" cfsqltype="cf_sql_numeric">
		AND v.host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
		AND s.host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
		</cfquery>
		<!--- If we have the preview the name is different --->
		<cfif thecolname EQ "video_preview">
			<cfset thefinalname = qry.vid_name_pre>
		<cfelse>
			<cfset thefinalname = qry.vid_name_org>
		</cfif>
		<!--- Put variables into struct for threads --->
		<cfset arguments.thestruct.hostid = session.hostid>
		<cfset arguments.thestruct.qry = qry>
		<cfset arguments.thestruct.thevideoid = thevideoid>
		<cfset arguments.thestruct.tempfolder = tempfolder>
		<cfset arguments.thestruct.art = art>
		<cfset arguments.thestruct.thefinalname = thefinalname>
		<cfset arguments.thestruct.thecolname = thecolname>
		<!--- Decide on local link or not --->
		<cfif qry.link_kind NEQ "lan">
			<!--- Local --->
			<cfif application.razuna.storage EQ "local">
				<cfif session.createzip EQ 'no'>
					<cffile action="copy" source="#arguments.thestruct.assetpath#/#arguments.thestruct.hostid#/#arguments.thestruct.qry.path_to_asset#/#arguments.thestruct.thefinalname#" destination="#arguments.thestruct.thepath#/outgoing/#arguments.thestruct.tempfolder#/#arguments.thestruct.zipname#" mode="775">
				<cfelse>
					<cfthread name="download#art##thevideoid#" intstruct="#arguments.thestruct#">
						<cffile action="copy" source="#attributes.intstruct.assetpath#/#attributes.intstruct.hostid#/#attributes.intstruct.qry.path_to_asset#/#attributes.intstruct.thefinalname#" destination="#attributes.intstruct.thepath#/outgoing/#attributes.intstruct.tempfolder#/#attributes.intstruct.art#/#attributes.intstruct.thefinalname#" mode="775">
					</cfthread>
				</cfif>
			<!--- Nirvanix --->
			<cfelseif application.razuna.storage EQ "nirvanix">
				<!--- Download file --->
				<cfif session.createzip EQ 'no'>
					<cfhttp url="#arguments.thestruct.qry.cloud_url_org#" file="#arguments.thestruct.thefinalname#" path="#arguments.thestruct.thepath#/outgoing/#arguments.thestruct.tempfolder#/#arguments.thestruct.zipname#"></cfhttp>
				<cfelse>
					<cfthread name="download#art##thevideoid#" intstruct="#arguments.thestruct#">
						<cfhttp url="#attributes.intstruct.qry.cloud_url_org#" file="#attributes.intstruct.thefinalname#" path="#attributes.intstruct.thepath#/outgoing/#attributes.intstruct.tempfolder#/#attributes.intstruct.art#"></cfhttp>
					</cfthread>
				</cfif>
			<!--- Amazon --->
			<cfelseif application.razuna.storage EQ "amazon">
				<!--- Download file --->
				<cfif session.createzip EQ 'no'>
					<cfinvoke component="amazon" method="Download">
						<cfinvokeargument name="key" value="/#arguments.thestruct.qry.path_to_asset#/#arguments.thestruct.thefinalname#">
						<cfinvokeargument name="theasset" value="#arguments.thestruct.thepath#/outgoing/#arguments.thestruct.tempfolder#/#arguments.thestruct.zipname#">
						<cfinvokeargument name="awsbucket" value="#arguments.thestruct.awsbucket#">
					</cfinvoke>
				<cfelse>
					<cfthread name="download#art##thevideoid#" intstruct="#arguments.thestruct#">
						<cfinvoke component="amazon" method="Download">
							<cfinvokeargument name="key" value="/#attributes.intstruct.qry.path_to_asset#/#attributes.intstruct.thefinalname#">
							<cfinvokeargument name="theasset" value="#attributes.intstruct.thepath#/outgoing/#attributes.intstruct.tempfolder#/#attributes.intstruct.art#/#attributes.intstruct.thefinalname#">
							<cfinvokeargument name="awsbucket" value="#attributes.intstruct.awsbucket#">
						</cfinvoke>
					</cfthread>
				</cfif>
			<!--- Akamai --->
			<cfelseif application.razuna.storage EQ "akamai">
				<!--- Download file --->
				<cfif session.createzip EQ 'no'>
					<cfhttp url="#arguments.thestruct.akaurl##arguments.thestruct.akavid#/#arguments.thestruct.thefinalname#" file="#arguments.thestruct.thefinalname#" path="#arguments.thestruct.thepath#/outgoing/#arguments.thestruct.tempfolder#/#arguments.thestruct.zipname#"></cfhttp>
				<cfelse>
					<cfthread name="download#art##thevideoid#" intstruct="#arguments.thestruct#">
						<cfhttp url="#attributes.intstruct.akaurl##attributes.intstruct.akavid#/#attributes.intstruct.thefinalname#" file="#attributes.intstruct.thefinalname#" path="#attributes.intstruct.thepath#/outgoing/#attributes.intstruct.tempfolder#/#attributes.intstruct.art#"></cfhttp>
					</cfthread>
				</cfif>
			</cfif>
		<!--- It is a local link --->
		<cfelseif qry.link_kind EQ "lan">
			<cfif session.createzip EQ 'no'>
				<cffile action="copy" source="#arguments.thestruct.qry.link_path_url#" destination="#arguments.thestruct.thepath#/outgoing/#arguments.thestruct.tempfolder#/#arguments.thestruct.zipname#" mode="775">
			<cfelse>
				<cfthread name="download#art##thevideoid#" intstruct="#arguments.thestruct#">
					<cffile action="copy" source="#attributes.intstruct.qry.link_path_url#" destination="#attributes.intstruct.thepath#/outgoing/#attributes.intstruct.tempfolder#/#attributes.intstruct.art#/#attributes.intstruct.thefinalname#" mode="775">
				</cfthread>
			</cfif>
		</cfif>
		<!--- Wait for the thread above until the file is downloaded fully --->
		<cfif session.createzip EQ 'yes'>
			<cfthread action="join" name="download#art##thevideoid#" />
		</cfif>
		<!--- Set extension --->
		<cfif thecolname EQ "video_preview">
			<cfset theext = "mov">
		<cfelse>
			<cfset theext = qry.vid_extension>
		</cfif>
		<!--- If the art id not thumb and original we need to get the name from the parent record --->
		<cfif qry.vid_group NEQ "">
			<cfquery name="qry" datasource="#variables.dsn#">
			SELECT vid_filename
			FROM #session.hostdbprefix#videos
			WHERE vid_id = <cfqueryparam value="#qry.vid_group#" cfsqltype="CF_SQL_VARCHAR">
			AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
			</cfquery>
		</cfif>
		<!--- If filename contains /\ --->
		<cfset thenewname = replace(qry.vid_filename,"/","-","all")>
		<cfset thenewname = replace(thenewname,"\","-","all")>
		<cfset thenewname = listfirst(thenewname, ".") & "." & theext>
		<!--- Rename the file --->
		<cfif session.createzip EQ 'no'>
			<cffile action="move" source="#arguments.thestruct.thepath#/outgoing/#tempfolder#/#arguments.thestruct.zipname#/#thefinalname#" destination="#arguments.thestruct.thepath#/outgoing/#tempfolder#/#arguments.thestruct.zipname#/#thenewname#">
		<cfelse>
			<cffile action="move" source="#arguments.thestruct.thepath#/outgoing/#tempfolder#/#art#/#thefinalname#" destination="#arguments.thestruct.thepath#/outgoing/#tempfolder#/#art#/#thenewname#">
		</cfif>
	</cfloop>
	<!--- Check that the zip name contains no spaces --->
	<cfset zipname = replace(arguments.thestruct.zipname,"/","-","all")>
	<cfset zipname = replace(zipname,"\","-","all")>
	<cfset zipname = replace(zipname, " ", "_", "All")>
	<cfif session.createzip EQ 'no'>
		<cfset zipname = zipname>
	<cfelse>
		<cfset zipname = zipname & ".zip">
	</cfif>
	<!--- Remove any file with the same name in this directory. Wrap in a cftry so if the file does not exist we don't have a error --->
	<cftry>
		<cfif session.createzip EQ 'no'>
			<cfdirectory action="delete" directory="#arguments.thestruct.thepath#/outgoing/#zipname#" recurse="yes">
		<cfelse>
			<cffile action="delete" file="#arguments.thestruct.thepath#/outgoing/#zipname#">
		</cfif>
		<cfcatch type="any"></cfcatch>
	</cftry>
	<cfif session.createzip EQ 'no'>
		<cfdirectory action="create" directory="#arguments.thestruct.thepath#/outgoing/#arguments.thestruct.zipname#" mode="775">
		<cffile action="copy" source="#arguments.thestruct.thepath#/outgoing/#tempfolder#/#arguments.thestruct.zipname#/#thenewname#" destination="#arguments.thestruct.thepath#/outgoing/#arguments.thestruct.zipname#" mode="775">
	<cfelse>
		<!--- Zip the folder --->
		<cfzip action="create" ZIPFILE="#arguments.thestruct.thepath#/outgoing/#zipname#" source="#arguments.thestruct.thepath#/outgoing/#tempfolder#" recurse="true" timeout="300" />
	</cfif>
	<!--- Remove the temp folder --->
	<cfdirectory action="delete" directory="#arguments.thestruct.thepath#/outgoing/#tempfolder#" recurse="yes">
	<!--- Return --->
	<cfreturn zipname>
</cffunction>

<!--- MOVE FILE IN THREADS --->
<cffunction name="movethread" output="false">
	<cfargument name="thestruct" type="struct">
	<!--- Loop over files --->
	<!--- <cfthread intstruct="#arguments.thestruct#"> --->
		<cfloop list="#arguments.thestruct.file_id#" delimiters="," index="fileid">
			<cfset arguments.thestruct.vid_id = "">
			<cfset arguments.thestruct.vid_id = listfirst(fileid,"-")>
			<cfif arguments.thestruct.vid_id NEQ "">
				<cfinvoke method="move" thestruct="#arguments.thestruct#" />
			</cfif>
		</cfloop>
	<!--- </cfthread> --->
	<!--- Flush Cache --->
	<cfset resetcachetoken("folders")>
	<cfset resetcachetoken("videos")>
</cffunction>

<!--- MOVE FILE --->
<cffunction name="move" output="false">
	<cfargument name="thestruct" type="struct">
		<cftry>
			<!--- Params --->
			<cfset arguments.thestruct.qryvid = "">
			<cfset arguments.thestruct.storage = application.razuna.storage>
			<!--- Move --->
			<cfinvoke method="getdetails" vid_id="#arguments.thestruct.vid_id#" ColumnList="v.vid_filename, v.folder_id_r, path_to_asset" returnvariable="arguments.thestruct.qryvid">
			<!--- Ignore if the folder id is the same --->
			<cfif arguments.thestruct.qryvid.recordcount NEQ 0 AND arguments.thestruct.folder_id NEQ arguments.thestruct.qryvid.folder_id_r>
				<!--- Update DB --->
				<cfquery datasource="#application.razuna.datasource#">
				UPDATE #session.hostdbprefix#videos
				SET folder_id_r = <cfqueryparam value="#arguments.thestruct.folder_id#" cfsqltype="CF_SQL_VARCHAR">
				WHERE vid_id = <cfqueryparam value="#arguments.thestruct.vid_id#" cfsqltype="CF_SQL_VARCHAR">
				AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
				</cfquery>
				<cfthread intstruct="#arguments.thestruct#">
					<!--- Update Dates --->
					<cfinvoke component="global" method="update_dates" type="vid" fileid="#attributes.intstruct.vid_id#" />
					<!--- Update Lucene --->
					<cfinvoke component="lucene" method="index_update" dsn="#application.razuna.datasource#" thestruct="#attributes.intstruct#" assetid="#attributes.intstruct.vid_id#" category="vid" notfile="T">
					<!--- MOVE ALL RELATED FOLDERS TOO!!!!!!! --->
					<cfinvoke method="moverelated" thestruct="#attributes.intstruct#">
					<!--- Execute workflow --->
					<cfset attributes.intstruct.fileid = attributes.intstruct.vid_id>
					<cfset attributes.intstruct.file_name = attributes.intstruct.qryvid.vid_filename>
					<cfset attributes.intstruct.thefiletype = "vid">
					<cfinvoke component="plugins" method="getactions" theaction="on_file_move" args="#attributes.intstruct#" />
					<cfset attributes.intstruct.folder_action = true>
					<cfset attributes.intstruct.folder_id = attributes.intstruct.folder_id>
					<cfinvoke component="plugins" method="getactions" theaction="on_file_move" args="#attributes.intstruct#" />
					<cfinvoke component="plugins" method="getactions" theaction="on_file_add" args="#attributes.intstruct#" />
				</cfthread>
				<!--- Log --->
				<cfset log_assets(theuserid=session.theuserid,logaction='Move',logdesc='Moved: #arguments.thestruct.qryvid.vid_filename#',logfiletype='vid',assetid=arguments.thestruct.vid_id)>
			</cfif>
			<cfcatch type="any">
				<cfinvoke component="debugme" method="email_dump" emailto="support@razuna.com" emailfrom="server@razuna.com" emailsubject="error in moving video" dump="#cfcatch#">
			</cfcatch>
		</cftry>
		<!--- Flush Cache --->
		<!--- <cfset resetcachetoken("folders")>
		<cfset variables.cachetoken = resetcachetoken("videos")> --->
	<cfreturn />
</cffunction>

<!--- Move related videos --->
<cffunction name="moverelated" output="false">
	<cfargument name="thestruct" type="struct">
	<!--- Get all that have the same img_id as related --->
	<cfquery datasource="#application.razuna.datasource#" name="qryintern">
	SELECT folder_id_r, vid_id
	FROM #session.hostdbprefix#videos
	WHERE vid_group = <cfqueryparam value="#arguments.thestruct.vid_id#" cfsqltype="CF_SQL_VARCHAR">
	AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
	</cfquery>
	<!--- Loop over the found records --->
	<cfif qryintern.recordcount NEQ 0>
		<cfloop query="qryintern">
			<!--- Update DB --->
			<cfquery datasource="#application.razuna.datasource#">
			UPDATE #session.hostdbprefix#videos
			SET folder_id_r = <cfqueryparam value="#arguments.thestruct.folder_id#" cfsqltype="CF_SQL_VARCHAR">
			WHERE vid_id = <cfqueryparam value="#vid_id#" cfsqltype="CF_SQL_VARCHAR">
			AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
			</cfquery>
			<!--- Update Lucene --->
			<cfinvoke component="lucene" method="index_update" dsn="#application.razuna.datasource#" thestruct="#arguments.thestruct#" assetid="#vid_id#" category="vid" notfile="T">
		</cfloop>
	</cfif>
	<cfreturn />
</cffunction>

<!--- Get description and keywords for print --->
<cffunction name="gettext" output="false">
	<cfargument name="qry" type="query">
	<!--- Get the cachetoken for here --->
	<cfset variables.cachetoken = getcachetoken("videos")>
	<!--- Query --->
	<cfquery datasource="#application.razuna.datasource#" name="qryintern" cachedwithin="1" region="razcache">
	SELECT /* #variables.cachetoken#gettextvid */ vid_id_r tid, vid_description description, vid_keywords keywords
	FROM #session.hostdbprefix#videos_text
	WHERE vid_id_r IN (<cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#ValueList(arguments.qry.id)#" list="true">)
	AND lang_id_r = <cfqueryparam cfsqltype="cf_sql_numeric" value="1">
	</cfquery>
	<!--- Return --->
	<cfreturn qryintern>
</cffunction>

<!--- Get rawmetadata --->
<cffunction name="getrawmetadata" output="false">
	<cfargument name="qry" type="query">
	<!--- Get the cachetoken for here --->
	<cfset variables.cachetoken = getcachetoken("videos")>
	<!--- Query --->
	<cfquery datasource="#application.razuna.datasource#" name="qryintern" cachedwithin="1" region="razcache">
	SELECT /* #variables.cachetoken#gettextrm */ vid_meta rawmetadata
	FROM #session.hostdbprefix#videos
	WHERE vid_id IN (<cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#ValueList(arguments.qry.id)#" list="true">)
	AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
	</cfquery>
	<!--- Return --->
	<cfreturn qryintern>
</cffunction>

<!--- GET RECORDS WITH EMTPY VALUES --->
<cffunction name="getempty" output="false">
	<cfargument name="thestruct" type="struct">
	<!--- Query --->
	<cfquery datasource="#application.razuna.datasource#" name="qry">
	SELECT
	folder_id_r, path_to_asset, cloud_url, cloud_url_org, link_kind, link_path_url, 
	path_to_asset, lucene_key, vid_name_org filenameorg, vid_id id, vid_filename
	FROM #session.hostdbprefix#videos
	WHERE (folder_id_r IS NULL OR folder_id_r = '')
	AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
	</cfquery>
	<!--- Return --->
	<cfreturn qry>
</cffunction>

<!--- Check for existing MD5 mash records --->
<cffunction name="checkmd5" output="false">
	<cfargument name="md5hash" type="string">
	<cfquery datasource="#application.razuna.datasource#" name="qry" cachedwithin="1" region="razcache">
	SELECT /* #variables.cachetoken#checkmd5 */ vid_id
	FROM #session.hostdbprefix#videos
	WHERE hashtag = <cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#arguments.md5hash#">
	AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
	</cfquery>
	<cfreturn qry />
</cffunction>

</cfcomponent>