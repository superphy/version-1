###


 File: intro_strains_search.coffee
 Desc: CoffeeScript for strains/search page intros
 Author: Jason Masih jason.masih@phac-aspc.gc.ca
 Date: Sept 5, 2014
 

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
  opts.splice(0,0,{intro: "You can use this page to search for information about the genomes in the database."})
  opts.splice(1,0,{
      element: document.querySelector('#genomes-menu-affix')
      intro: "You can perform a genome search in three different ways: using the genome list, phylogenetic tree, or map."
      position: 'bottom'
      })
  opts.splice(2,0,{
      element: document.querySelector('.download-view-link')
      intro: "You have the option to download the content of any of these views."
      position: 'left'
    })
  opts.splice(4,1,{
      element: document.querySelector('#genome_table1')
      intro: "These are the names of the genomes in the database.  Click on the magnifying glass for a detailed overview of each genome."
      position: 'right'
      })
  opts.splice(7,1,{
      element: document.querySelector('#genome_tree2')
      intro: "You can also click the blue circles to select genomes.  Pan by clicking and dragging.  Clicking on the '+' and '-' symbols will expand or collapse each clade.  Use the clickwheel on your mouse to zoom."
      position: 'right'
      })
  opts.splice(11,1,{
      element: document.querySelector('#genome_map3')
      intro: "The genomes corresponding to locations on the map are shown here.  Click the magnifying glass for a detailed overview of each genome."
      position: 'top'
      })

  # Create introJS object
  
  intro = introJs()

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
          when 4
            window.scrollTo(0,0)
          when 5
            window.scrollTo(0,800)
          when 6
            window.scrollTo(0,800)
          when 10
            window.scrollTo(0,1700)
          when 11
            window.scrollTo(0,1700)
          when 12
            window.scrollTo(0,1700)

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

