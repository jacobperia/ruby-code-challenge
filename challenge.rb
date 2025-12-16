# frozen_string_literal: true

require 'json'
require 'json-schema' # Gem for validating the data. Install gem before running the script.

# This class loads data from the json files in the data folder and generates the expected output data
class DataLoader
  # Schemas for the users and companies data
  SCHEMAS = {
    'users' => {
      'type' => 'object',
      'required' => %w[id first_name last_name email company_id email_status active_status tokens],
      'properties' => {
        'id' => { 'type' => 'integer' },
        'first_name' => { 'type' => 'string' },
        'last_name' => { 'type' => 'string' },
        'email' => { 'type' => 'string' },
        'company_id' => { 'type' => 'integer' },
        'email_status' => { 'type' => 'boolean' },
        'active_status' => { 'type' => 'boolean' },
        'tokens' => { 'type' => 'integer' }
      }
    },
    'companies' => {
      'type' => 'object',
      'required' => %w[id name top_up email_status],
      'properties' => {
        'id' => { 'type' => 'integer' },
        'name' => { 'type' => 'string' },
        'top_up' => { 'type' => 'integer' },
        'email_status' => { 'type' => 'boolean' }
      }
    }
  }.freeze

  def initialize
    # Load users and companies data from their respective files
    @users = load_data_from_file('users')
    @companies = load_data_from_file('companies')
    # Sort companies by id
    @companies = @companies.sort_by { |company| company['id'] }
  end

  # Load data from a file
  def load_data_from_file(table_name)
    file_path = File.join(__dir__, 'data', "#{table_name}.json")
    # Raise an error if the file does not exist
    raise "#{table_name} does not exist" unless File.exist?(file_path)

    file = File.read(file_path)

    begin
      data = JSON.parse(file)
    rescue JSON::ParserError
      # Raise an error if the file is invalid
      raise "#{table_name} is invalid"
    end

    # Raise an error if the file not an array oris empty
    raise "#{table_name} is not an array" unless data.is_a?(Array)
    raise "#{table_name} is empty" if data.empty?

    validate_data(table_name, data)

    data
  end

  # Validate the data for presence and type against the schema
  def validate_data(table_name, data)
    schema = SCHEMAS[table_name]

    begin
      data.each do |record|
        JSON::Validator.validate!(schema, record)
      end
    rescue JSON::Schema::ValidationError => e
      # Raise an error if the data is invalid
      raise "Invalid data found in #{table_name}.json"
    end
  end

  # Primary method that writes the output data to the output.txt file
  def write_output_data
    File.open('output.txt', 'w') do |file|
      file.write("\n") # Add a newline

      # Write the output data for each company
      @companies.each do |company|
        user_data = segregate_user_data(company)
        next if user_data[:active_users_count].zero?

        file.write("\tCompany Id: #{company['id']}\n")
        file.write("\tCompany Name: #{company['name']}\n")
        write_user_data(file, user_data[:users_emailed], company, 'Users Emailed:')
        write_user_data(file, user_data[:users_not_emailed], company, 'Users Not Emailed:')
        total_top_ups = user_data[:active_users_count] * company['top_up']
        file.write("\t\tTotal amount of top ups for #{company['name']}: #{total_top_ups}\n\n")
      end
    end
  end

  # Write the user data to the file
  def write_user_data(file, users, company, title)
    # Sort the users by last name
    users.sort_by! { |user| user['last_name'] }

    file.write("\t#{title}\n")

    users.each do |user|
      # Calculate the new token balance
      new_balance = user['tokens'] + company['top_up']
      file.write("\t\t#{user['last_name']}, #{user['first_name']}, #{user['email']}\n")
      file.write("\t\t  Previous Token Balance, #{user['tokens']}\n")
      file.write("\t\t  New Token Balance #{new_balance}\n")
    end
  end

  # Segregate the users inot those who were emailed and those who were not
  def segregate_user_data(company)
    users_emailed = []
    users_not_emailed = []
    users = find_active_company_users(company['id'])

    users.each do |user|
      # Email users who have email status true for themselves and also their company. Don't email other users.
      if company['email_status'] && user['email_status']
        users_emailed << user
      else
        users_not_emailed << user
      end
    end

    { users_emailed: users_emailed, users_not_emailed: users_not_emailed, active_users_count: users.count }
  end

  # Find active users for a company
  def find_active_company_users(company_id)
    @users.select { |user| user['company_id'] == company_id && user['active_status'] == true }
  end
end

DataLoader.new.write_output_data
