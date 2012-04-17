# Provides basic Basecamp integration.
#   http://github.com/marshall007
#
# You must set the following variables:
#   HUBOT_BASECAMP_TOKEN = <Authentication API token>
#   HUBOT_BASECAMP_COMPANY = <Your company name>
#
# list|show [active, inactive, archived] basecamp projects - get a list of Basecamp projects 
#

module.exports = (robot) ->
	robot.respond /(list |show )(active|inactive|archived|\b)(\s\b)?basecamp projects/i, (msg) ->
		project_status = "#{msg.match[2]}"
		if project_status.length is 0
			project_status = "active"
		project_status = project_status[0].toUpperCase() + project_status[1..-1].toLowerCase()
		
		basecamp = new Basecamp msg, process.env.HUBOT_BASECAMP_COMPANY, process.env.HUBOT_BASECAMP_TOKEN
		basecamp.getProjects project_status, (err, message) ->
			if err?
				msg.send "#{err}"
			else
				msg.send "#{message}"

	robot.hear /(https\:\/\/\S+basecamphq.com)\/([a-z-_]+)\/([0-9]+)/i, (msg) ->
		domain = "#{msg.match[1]}"
		type = "#{msg.match[2]}".replace /\s/g, "_"
		id = "#{msg.match[3]}"
		basecamp = new Basecamp msg, process.env.HUBOT_BASECAMP_COMPANY, process.env.HUBOT_BASECAMP_TOKEN
		
		if domain is basecamp.url()
			basecamp.getById type, id, (err, message) ->
				if err?
					msg.send "#{err}"
				else
					msg.send "#{message}"


# Classes

class Basecamp
	constructor: (msg, company, token) ->
		@msg = msg
		@company = company
		@token = token
		
	url: ->
		"https://#{@company}.basecamphq.com"
		
	authdata: ->
		new Buffer(@token+':X').toString('base64')
		
	getById: (type, id, callback) ->
		xml2js = require('xml2js')
		api_url = @url() + "/#{type}/#{id}.xml"
		console.log api_url
		@getBasecamp api_url, (err, data) ->
			if err? or not data?
				callback err
			else
				resp_str = "Basecamp Item: \n"
				(new xml2js.Parser()).parseString data, (err, json) ->
					console.log json.id['#']
					#for item in json['todo-list']
					resp_str += "#{json.name} [#{json.id}]\n"
				callback null, resp_str
	
	getProjects: (project_status, callback) ->
		xml2js = require('xml2js')
		api_url = @url() + "/projects.xml"
		
		@getBasecamp api_url, (err, data) ->
			if err? or not data?
				callback err
			else
				resp_str = "#{project_status} Basecamp Projects: \n"
				(new xml2js.Parser()).parseString data, (err, json) ->
					for project in json.project when project.status is project_status.toLowerCase()
						resp_str += "#{project.name} [#{project.status}]\n"
				callback null, resp_str
	

	getBasecamp: (api_url, callback) ->
		@msg.http(api_url)
			.header('Authorization', 'Basic ' + @authdata())
			.header('Accept', 'application/xml')
			.get() (err, res, body) ->
				if res.statusCode is 200
					callback null, body
				else if err?
					callback err
				else
					callback "There was a problem contacting Basecamp."