require 'rubygems'
require 'active_record'
require 'yaml'
require 'activerecord-mysql2-adapter'

#load these entries into an ActiveRecord table. you may need another data structure to store the names of each of the data points (like age, gender, etc)
dbconfig = YAML::load(File.open('database.yml'))
ActiveRecord::Base.establish_connection(dbconfig)

class Submission < ActiveRecord::Base
end

def show_single_item
	pr = Submission.find(:first)
	puts "showing first submission from the db below", pr.id
end

def show_single_people
	pr = Submission.where("relationship_status = \"single\"")
	puts pr

end



#this script takes a csv file as input
if (ARGV.length != 1)
	puts "Wrong number of args specified. Please specify a csv file."
	exit(1)
end

survey_name = ARGV[0]

# The demographics are represented by the strings ending with
#demographic*, e.g. demographic_income, demographic_age
#

#our dataset is going to be anarray of hashes. the keys will be things like 'Q9', and the values will be hashes
# the inner hashes will have the possible choices as keys and the number of people who chose those choices as values
data_set = Array.new

#this has keys being the answers, and the value is the index in the data_set array
answer_names = Array.new

line_num = 0
File.open(survey_name).each do |line|
	attributes = line.strip.split("\",\"")
	#the first line consists of all the attributes
	if (line_num == 0)
		attributes.each_with_index do |attribute, index|
			#this means that it is the response to a question
			if (attribute.start_with?("Answer"))

				data_set.push(Hash.new)
				
				#this keeps track of the name of the answer so that we can map it to its value
				answer_names.push(attribute)
			end

		end
	else
		#for all the other lines
		#print "length of attributes array is #{attributes.length}"


		#the hash represents all the data in a submission
		submission_params = Hash.new

		# this will represent the response_list field of the database entry
		#it will take the form "attribute_name:response attribute_name:response..."
		submission_responses = ""


		for i in (attributes.length - data_set.length)..(attributes.length - 1)
			#print "i is #{i}\n"
		#	print "attribute is #{attributes[i]}\n"
			#this value is the index in the data_set variable, which only contains answer values
			index_in_data_set = i - (attributes.length - data_set.length)

			#this is the name of the attribute
			attribute_name = answer_names[index_in_data_set]

			#this is the value of the attribute
			attribute_value = attributes[i].chomp("\"")

			if (attribute_name =~ /(.*)demographic_(.*)/)
				#puts "attribute name is: " + attribute_name

				#get the database table entry name:
				result = attribute_name.scan(/(.*)demographic_(.*)/)
				db_column_name = result[0].last.to_sym
				submission_params[db_column_name] = attribute_value

			else
				submission_responses += attribute_name + ":" + attribute_value + "~"				
			end



			data_set[index_in_data_set][attribute_value] = data_set[index_in_data_set].fetch(attribute_value, 0) + 1

			#print "attribute is: #{attribute} and index is #{index}\n"
			#(data_set[index])[attribute] = (data_set[index]).fetch(attribute, 0) + 1;
		end

		submission_params[:response_list] = submission_responses
		submission_params[:survey_name] = survey_name
		new_submission = Submission.create(submission_params)
	end
	line_num += 1
	#print "#{line_num += 1} #{line}"
#	print "length of data_set array is #{data_set.length} and length of attributes array is #{attributes.length}\n"
end

data_set.each do |answer_hash|
	print "\n\n"
	answer_array = answer_hash.sort_by {|k, v| v}.reverse

	names = ""

	answer_array.each do |answer_obj|
		names = names + "#{answer_obj[0]},"
		#print "choice is: #{answer_obj[0]} and value is: #{answer_obj[1]}\n"
	end
	print "#{names[0..-2]}\n"

	values = ""
	answer_array.each do |answer_obj|
		values = values + "#{answer_obj[1]},"
	end
	print "#{values[0..-2]}\n"
end

