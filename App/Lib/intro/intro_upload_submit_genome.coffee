###


 File: intro_upload_submit_genome
 Desc: CoffeeScript for upload/submit_genome page intros
 Author: Jason Masih jason.masih@phac-aspc.gc.ca
 Date: October 1, 2014
 

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
          element: document.querySelector('#requiredFields')
          intro: "Fill out all the required fields."
          position: 'left'
        },
        {
          element: document.querySelector('#attachFile')
          intro: "Click here to select a file to upload a multi-fasta file containing genomic DNA."
          position: 'right'
        },
        {
          element: document.querySelector('#additionalFields')
          intro: "Fill out any additional fields."
          position: 'left'
        },
        {
          element: document.querySelector('#submitGenome')
          intro: "Click here to submit the form and upload your genome."
          position: 'top'
        },
        {
          element: document.querySelector('#clearform')
          intro: "Click here to reset the form."
          position: 'top'
        }
      ]
    }
  )

  intro.start()

  intro.oncomplete ->
    window.scrollTo(0,0)

  # Coffeescript will return the value of 
	# the last statement from function
  false

# END FUNC

# Make this function visible in global namespace
# If there isnt a function already called startIntro
unless root.startIntro
  root.startIntro = startIntro