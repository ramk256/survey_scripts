require 'rubygems'
require 'active_record'
require 'yaml'
require 'activerecord-mysql2-adapter'

class Submission < ActiveRecord::Base
end

# a distribution
class Distribution
	attr_accessor :dist_array, :name
	#the constructor takes in a name value.
	#IMPORTANT: the name must match an attribute of the dataset that is being iterated over
	#it also takes in an array, where:
	#each entry is a 2 element array that consists of a value or range and the second
	#entry consists of a decimal number that represents the percent of U.S. population
	#that fits into the category described by the first element

	#example, for income: [[["Less than $24,999" , 25]]
	def initialize(name, dist_array)
    	@dist_array = dist_array
    	@name = name
    end

    # this method returns an array:
    # 1st element is a set of weights 
    # 2nd element is an array to map submissions to the correct weight
    def get_weights_submission_map(pr)
    	weights = Array.new(@dist_array.length, 0) 
		each_entry = Array.new(pr.length, 0)

		puts "calculating weights for: " + @name
		pr.each_with_index do |submission, index|
			if (submission.respond_to?(@name))
				value = submission.send(@name)
			else
				puts "#{@name} is not a valid attribute for the survey submission!"
				exit(1)
			end

			# we only want each submission to fall into one bucket
			already_counted = false
			dist_array.each_with_index do |entry, dem_index|
				if (((entry[0].instance_of?(String) && value == entry[0]) ||
					(entry[0].instance_of?(Regexp) && value =~ entry[0]) ||
					(entry[0].length == 2 && (value.to_i >= entry[0][0] && value.to_i <= entry[0][1]))) &&
					!already_counted)
					weights[dem_index] += 1
					each_entry[index] = dem_index 
					already_counted = true
				end
			end
		end

		#currently, weights are just the number of each category. we need to
		#divide the value in the dist_array with this value to get the proper
		#weight
		@dist_array.each_with_index do |entry, dem_index|
			weights[dem_index] = entry[1].to_f / weights[dem_index].to_f
			puts "weight is: #{weights[dem_index]}"
		end

		output = Array.new
		output << weights << each_entry

		return output
    end
end

#this method takes in a data_set and prints out the results in CSV-friendly
#format
def print_results(data_set)
	data_set.each_pair do |key, value|
		puts "key is: " + key

		answer_array = value.sort_by {|k, v| v}.reverse

		names = ""

		answer_array.each do |answer_obj|
			names = names + "#{answer_obj[0]},"
		end
		print "#{names[0..-2]}\n"

		values = ""
		answer_array.each do |answer_obj|
			values = values + "#{answer_obj[1]},"
		end
		print "#{values[0..-2]}\n"
	end
end


#this function takes in an array of distributions and then averages
#them out based on how many there are 
#for example, it takes in 
def compute_datasets(pr, distribution_array)
	data_set = Hash.new
	initialize_data_set = parse_response_list(pr.first.response_list, pr.first)

	initialize_data_set.each_key do |key|
		data_set[key] = Hash.new
	end

	weights_map_array = Array.new
	distribution_array.each do |distribution|
		weights_map_array << distribution.get_weights_submission_map(pr)
	end

	#for each submission
	pr.each_with_index do |submission, index|
		submission_hash = parse_response_list(submission.response_list, submission)
		#for each of the responses to the question
		submission_hash.each_pair do |key, value|
			if (!key.nil? && !value.nil?)
				weight_value = 0
				weights_map_array.each do |weights_map|
					#weights_map[1][index] represents the index into the weights array, which is
					#weights_map[0]
					weight_value += weights_map[0][weights_map[1][index]]
				end

				#we average out by the number of distributions
				weight_value = weight_value / weights_map_array.length

				data_set[key][value] = data_set[key].fetch(value, 0) + weight_value
			end	
		end
	end

	return data_set
end


#this function takes in a response list and returns the set of key-values
def parse_response_list(rl, submission) 
	pairs_array = rl.split("~")
	response_hash = Hash.new

	pairs_array.each do |pair|
		key_value = pair.split(":")
		response_hash[key_value[0]] = key_value[1]
	end

	return response_hash
end

#load these entries into an ActiveRecord table. you may need another data structure to store the names of each of the data points (like age, gender, etc)
dbconfig = YAML::load(File.open('database.yml'))
ActiveRecord::Base.establish_connection(dbconfig)

#pr = Submission.where("survey_name=\"11:11survey.csv\"")
pr = Submission.where("survey_name=\"gym_survey.csv\"")
income_distribution = Distribution.new("income", [["Less than $24,999", 25.0], ["$25,000 - $49,999" , 25.0], ["$50,000 - $74,999", 18.0], ["$75,000 - $99,999", 12.0], [/.*/, 20.0]])
age_distribution = Distribution.new("age", [[[18, 29], 24.0], [[30, 39], 18.0], [[40, 49], 19.0], [[50, 59], 16.0], [[60, 130], 23.0]])
gender_distribution = Distribution.new("gender", [["Male", 48.0], ["Female", 52.0]])



puts "\n\n Combining all of them! \n\n"

print_results(compute_datasets(pr, [income_distribution, age_distribution, gender_distribution]))

#normalize_income
