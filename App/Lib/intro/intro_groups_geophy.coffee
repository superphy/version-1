###


 File: intro_groups_geophy.coffee
 Desc: CoffeeScript for groups/geophy page intros
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
  

  opts = viewController.introOptions()
  opts.splice(0,0,{intro: "The GeoPhy page provides users with the opportunity to view genome data simultaneously on a map and on a tree to answer any potential epidemiological questions."})
  opts.splice(1,0,{
    element: document.querySelector('#submit-btn')
    intro: "Click 'Highlight Genomes' to isolate your selected genomes on the map and on the tree."
    position: 'bottom'
    })
  opts.splice(2,0,{
    element: document.querySelector('#reset-btn')
    intro: "Click 'Reset Views' to reset genome selections, the map, and the tree."
    position: 'bottom'
    })
  opts.splice(6,1,{
    element: document.querySelector('#genome_map1')
    intro: "The genomes corresponding to locations on the map are shown here.  Check the boxes of any genomes you would like to select."
    position: 'right'
    })    
  # Create introJS object
  intro = introJs()


  # Set intros for each element
  # in order they appear
  intro.setOptions(
    {
      steps : opts
    }
  )

  # Prevents intro elements from appearing out of view
  intro.onbeforechange (targetElement) ->
    $.each opts, (index, step) ->
      if $(targetElement).is(step.element)
        switch index
          when 2
            window.scrollTo(0,0)
          when 3
            window.scrollTo(0,0)
          when 4
            window.scrollTo(0,0)
          when 5
            window.scrollTo(0,0)
          when 8
            window.scrollTo(0,0)
          when 9
            window.scrollTo(0,0)
          when 10
            window.scrollTo(0,0)
          when 11
            window.scrollTo(0,0)

  intro.onchange (targetElement) ->
     $.each opts, (index, step) ->
        if $(targetElement).is(step.element)
          switch index
            when 3
              document.getElementById('sidebar-wrapper').style.position = "absolute"
            when 4
              document.getElementById('sidebar-wrapper').style.position = "fixed"

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

