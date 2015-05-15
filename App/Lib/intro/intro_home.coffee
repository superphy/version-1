###


 File: intro_home.coffee
 Desc: CoffeeScript for home page intro
 Author: Jason Masih jason.masih@phac-aspc.gc.ca
 Date: Sept 9, 2014
 

 Name all files like this intro_[page_name].coffee

 Compiled coffeescript files will be sent to App/Lib/js/. This directory
 contains all Superphy's js files. So this naming scheme will help ensure 
 there are no filename collisions.

 Cakefile has a routine to compile and output the coffeescript files
 in intro/ to js/. To run:

   cake intro

###

# Default in coffescript is to not put any functions into global namespace
# Global namespace, depending on environment, can be referenced by 'exports' or
# 'this' variables
#
# Here we find which one is being used, and assign it to the root variable
root = exports ? this


# FUNC startIntro
# Starts the introJS intro
#
# USAGE startIntro()
# 
# RETURNS
# Boolean
#    
startIntro = ->
  
  # Create introJS object
  intro = introJs()


  # Set intros for each element
  # in order they appear
  intro.setOptions(
    {
      steps : [
        {
          intro: "Welcome to SuperPhy, a user-friendly, integrated platform for the predictive genomic analyses of <i>Escherichia coli</i>.  The features of SuperPhy are as follows: "
        }
        {
          element: document.querySelector("#strains")
          intro: "Search for information about each genome."
        }
        {
          element: document.querySelector("#groups")
          intro: "Compare and analyze groups of genomes."
        }
        {
          element: document.querySelector("#genes")
          intro: "Check for the presence of specific virulence factors and antimicrobial resistance genes in genomes of interest."
        }
        {
          element: document.querySelector("#geophy")
          intro: "View genome data simultaneously on a map and on a tree."
        }
        {
          element: document.querySelector("#genome-uploader")
          intro: "Upload your own genome data for analysis."
        }
      ]
    }
  )
  
  intro.start()

  # Coffeescript will return the value of 
	# the last statement from function
  false

# Make this function visible in global namespace
# If there isnt a function already called startIntro
unless root.startIntro
  root.startIntro = startIntro


