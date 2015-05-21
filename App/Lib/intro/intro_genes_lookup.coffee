###


 File: intro_genes_lookup.coffee
 Desc: Coffeescript for genes/lookup page intros
 Author: Jason Masih jason.masih@phac-aspc.gc.ca
 Date: Sept 22, 2014
 

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
          element: document.querySelector('#vfgenes')
          intro: "Use this to look up detailed information about individual virulence factors.  The search bar can be used to filter virulence factors in the list."
          position: 'top'
        },
        {
          element: document.querySelector('#amrgenes')
          intro: "Use this to look up detailed information about individual antimicrobial resistance genes. The search bar can be used to filter antimicrobial resistance factors in the list."
          position: 'top'
        }
      ]
    }
  )

  intro.start()

  # Coffeescript will return the value of 
  # the last statement from function
  false

# END FUNC

# Make this function visible in global namespace
# If there isnt a function already called startIntro
unless root.startIntro
  root.startIntro = startIntro

