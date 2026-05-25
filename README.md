# SAFARI_CONNECT
project 2
### data cleaning with power BI ###
  1) managed to remove duplicates (just 1) from 290 to 289 - booking_Id
  2) cleaned and standardized names by converting them to proper case and removing inconsistencies in capitalizations
  3) the raw dataset contained inconsistent phone number entries(2578297365, 07-3728-826, missing data(null values) - converted to text to remove the 0 and + , Next ,trim and clean (invisible spaces and characters that break text-matching rules).
     To fix the prefixes without creating step-by-step dependency errors, a single Custom Column was engineered using advanced M-code conditional logic:
     the Null Safe-Guard: The code first checks if a cell is null or completely empty (""). If it is, it leaves it alone. This successfully stopped the 4% error rate we initially encountered when trying to measure the length of non-existent text.
     The "+254" Pass: If the number already starts correctly with +254, the formula skips it and leaves it untouched.The "254" Fix: If a number starts with 254 but misses the plus sign, the formula concatenates a + to the front ("+" & CleanText).
     the Leading Zero "0" Strip: If a number starts with a local 0, the formula drops that single first character using Text.End() and seamlessly grafts +254 onto the remaining string.
     the Raw "7" or "1" Inject: For numbers starting directly with the provider prefix (like 7... or 1... for Safaricom/Airtel), the formula directly prepends +254 to standardise the length.
     perfectly standardized all phone records into a uniform and recognized string.

     4)Fare had a mix of plain numbers and text (ksh) . stripped the ksh(replace value) remained with plain numbers.
     Trimmed tto cutt out spaces at the beginning/end of the numbers..
     changed the data type from Text to decimal, currency - ksh

     5)Gender column -had mixed ways male,female,F,M,Male,Female
     capitalised each worf to fix the casing
     replaced value to change the single letters to full words ,advanced option -match entire cells content box so that power query only changes the single letter without breaking the existting words

     6)
