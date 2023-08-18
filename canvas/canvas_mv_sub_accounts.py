#!/bin/env python

# https://canvasapi.readthedocs.io/en/stable/getting-started.html

# Import the Canvas class
from canvasapi import Canvas
from canvasapi.exceptions import CanvasException
from pprint import pprint
import logging
import sys

logger = logging.getLogger("canvasapi")
handler = logging.StreamHandler(sys.stdout)
formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')

handler.setLevel(logging.INFO)
handler.setFormatter(formatter)
logger.addHandler(handler)
logger.setLevel(logging.INFO)

# Canvas API URL
API_URL = ""
# Canvas API key
API_KEY = ""

# Initialize a new Canvas object
canvas = Canvas(API_URL, API_KEY)

# try:
    # course = canvas.get_course(776)
# except CanvasException as e:
    # print(e)


# List sub accounts 

account = canvas.get_account(1)
numcourse = 0

#Lists for action. Updates in place wrecks API pagination
list_sub_account = list()
list_courses = list()
for sub_account in account.get_subaccounts(recursive=False):
    
    # pprint(dir(sub_account))
    # pprint(vars(sub_account))
    print(f'Sub Account: {sub_account}')
    if "Manually-Created Courses" in sub_account.name: 
        continue 

    if "DemoShell DemoShell" in sub_account.name: 
        continue
        
    list_sub_account.append(sub_account)
    
    # https://canvasapi.readthedocs.io/en/stable/examples.html#accounts
    courses = sub_account.get_courses()
    for course in courses:
        print(f'       {course.name}')
        print(f'       Course Nuber #{course.id}')
        list_courses.append(course)
        # pprint(dir(course))
        # pprint(vars(course))
    
#Do the Work

for course in list_courses:
    print(f'Update Course: {course}')
    try:
        course.update(course={'account_id': 1})
    except CanvasException as e:
        print(e)
    
for sub_account in list_sub_account:
    print(f'Deleting Subaccount: {sub_account}')
    try:
        sub_account.delete()
    except CanvasException as e:
        print(e)
        print(f'sub_account {sub_account} not deleted')
        # sys.exit()        
    # Delete Sub_Account        


# https://canvas.instructure.com/doc/api/accounts.html#method.accounts.courses_api
