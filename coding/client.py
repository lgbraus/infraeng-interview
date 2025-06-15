"""
Small client that will do the following.
- Read the example.json file, validate that it is valid JSON.
- Modify the read structure to only include objects that have private set to false
- Connect as a web client to a web service over HTTPS
- Make a REST POST call, posting the selected JSON fragment to the endpoint
  /service/generate
- The web server response will be a JSON map of objects. Print the key of every
  object that has a child attribute "valid" set to true
"""

import json
import logging

import requests
from requests.exceptions import RequestException

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s')


def read_validate_json_file(file_path):
    """
    Read the example.json file, validate that it is valid JSON.

    Exception Handling Of Python FileNotFoundError:
    https://www.geeksforgeeks.org/python/why-am-i-getting-a-filenotfounderror-in-python/

    Exception Handling Of Python JSONDecodeError:
    https://www.geeksforgeeks.org/python/json-parsing-errors-in-python/
    """

    try:
        with open(file_path, 'r', encoding='utf-8') as file:
            data = json.load(file)
            logging.info("JSON file read and validated successfully.")
            return data
    except FileNotFoundError:
        logging.error("File not found: %s", file_path)
        return None
    except json.JSONDecodeError as e:
        logging.error("Invalid JSON in file %s: %s", file_path, e)
        return None
    except IOError as e:
        logging.error("An error occurred while reading the file: %s", e)
        return None


def filter_data(data):
    """
    Modify the read structure to only include objects that have private set to false.
    """

    if not data:
        logging.info("Input data is empty")
        return {}

    if not isinstance(data, dict):
        logging.error("Expected dict.")
        return {}

    filtered_data = {}

    for key, value in data.items():
        if isinstance(value, dict):
            if value.get('private') is False:
                filtered_data[key] = value

    return filtered_data


def make_post_request(base_url, endpoint='', data=None, timeout=30):
    """
    Connect as a web client to a web service over HTTPS
    Make a REST POST call, posting the selected JSON fragment to the endpoint
    /service/generate

    Exception Handling Of Python Requests Module:
    https://www.geeksforgeeks.org/python/exception-handling-of-python-requests-module
    """

    if not data:
        logging.error("No data provided for POST request.")
        return None

    url = f"{base_url}{endpoint}"
    headers = {'Content-Type': 'application/json'}

    try:
        response = requests.post(
            url,
            headers=headers,
            json=data,
            timeout=timeout)
        response.raise_for_status()
        logging.info("Request to %s successful. Status code: %s",
                     url, response.status_code)
        return response.json()

    except RequestException as e:
        logging.error("Request failed: %s", e)
        return None


def process_response(response):
    """
    Print the key of every object that has a child attribute "valid" set to true
    """

    if not response:
        logging.error("No response to process.")
        return

    if not isinstance(response, dict):
        logging.error("Expected response to be a JSON map of objects")
        return

    valid_keys = []

    for key, value in response.items():
        if isinstance(value, dict) and value.get('valid') is True:
            valid_keys.append(key)
            print(key)
            logging.info("Valid object key: %s", key)

    if valid_keys:
        logging.info("Found %d objects with valid set to true",
                     len(valid_keys))
    else:
        logging.info("No objects found with valid set to true")


def main():
    """Main function to run the client."""

    base_url = 'https://test-api.example.com'
    endpoint = '/service/generate'
    file_path = 'example.json'

    data = read_validate_json_file(file_path)
    if not data:
        logging.error("Failed to read or validate file.")
        return

    filtered_data = filter_data(data)
    if not filtered_data:
        logging.warning("No objects with private set to false found.")
        return

    response = make_post_request(base_url, endpoint, filtered_data)
    if not response:
        logging.error("Failed to get a valid response.")
        return

    process_response(response)


if __name__ == "__main__":
    main()
