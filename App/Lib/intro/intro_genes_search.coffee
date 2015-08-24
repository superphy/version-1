###


 File: intro_genes_search.coffee
 Desc: CoffeeScript for genes/search page intros
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
  
  # Array of intros from common elements (e.g. table, tree, map)
  opts = viewController.introOptions()
  
  # Create introJS object
  intro = introJs()

  # Starts the intro on the "Select Genes" tab
  $('#gene-search-tabs a[href="#gene-search-querygenes"]').tab 'show'

  
  # "Select Genes" tab intros
  opts.splice(0,0,{
          intro: "You can use this page to determine whether or not specified virulence factors and antimicrobial resistance genes are present in genomes of interest."
          })
  opts.splice(1,0,{
          element: document.querySelector('#gene-search-tabs')
          intro: "Use the 'Select Genes' tab to select virulence factors and antimicrobial resistance genes.  Then, use the 'Select Genomes' tab to select your genomes of interest.  Finally, use the 'Submit Query' tab to submit your query.  Modifications to your selections can be made at any time."
          position: 'top'
          })
  # opts.splice(2,0,{
  #         element: document.querySelector('#gene-lookup')
  #         intro: "Click here for detailed information on specific virulence factors and antimicrobial resistance genes."
  #         position: 'left'
  #         })
  opts.splice(2,0,{
          element: document.querySelector('.affix-top')
          intro: "You can choose your search method by selecting virulence factors or by antimicrobial resistance genes.  Your search can consist of either or both virulence factors and antimicrobial resistance genes."
          position: 'bottom'
          })
  opts.splice(3,0,{
          element: document.querySelector('#vf-selected-list')
          intro: "Your selected virulence factors will appear here.  Click the blue 'X' next to a factor to remove it."
          position: 'bottom'
          })
  opts.splice(4,0,{
          element: document.querySelector('#vf-autocomplete')
          intro: "Use this to filter virulence factors by inputted gene name."
          position: 'bottom'
          })
  opts.splice(5,0,{
          element: document.querySelector('#vf-table')
          intro: "Select one or more virulence factors to search for their presence in your specified genomes.  Click the links above to select or unselect all of the virulence factors."
          position: 'right'
          })
  opts.splice(6,0,{
          element: document.querySelector("#vf-categories")
          intro: "You can select from these categories to refine the list of genes.  Click the 'Reset' button to reset your selections."
          position: 'left'
          })
  opts.splice(7,0,{
          element: document.querySelector('#amr-selected-list')
          intro: "Your selected antimicrobial resistance genes will appear here.  Click the blue 'X' next to a factor to remove it."
          position: 'bottom'
          })
  opts.splice(8,0,{
          element: document.querySelector('#amr-autocomplete')
          intro: "Use this to filter antimicrobial resistance genes by inputted gene name."
          position: 'bottom'
          })
  opts.splice(9,0,{
          element: document.querySelector('#amr-table')
          intro: "Select one or more antimicrobial resistance genes to search for their presence in your specified genomes.  Click the links above to select or unselect all of the antimicrobial resistance genes."
          position: 'right'
          })
  opts.splice(10,0,{
          element: document.querySelector("#amr-categories")
          intro: "You can select from these categories to refine the list of genes.  Click the 'Reset' button to reset your selections."
          position: 'left'
          })
  opts.splice(11,0,{
          element: document.querySelector('#next-btn1')
          intro: "Click here to proceed and select your genomes."
          position: 'right'
          })
  # "Select Genomes" tab intros
  opts.splice(12,0,{
          element: document.querySelector('#superphy-icon-menu')
          intro: "You can perform a genome search in three different ways: using the genome list, phylogenetic tree, or map."
          position: 'top'
          })
  opts.splice(16,0,{
          element: document.querySelector('.download-view-link')
          intro: "You have the option to download the content of any of these views."
          position: 'left'
          })
  opts.splice(17,0,{
          element: document.querySelector('#selected_genomes')
          intro: "Your selected genomes will appear here.  Click the blue 'X' next to a factor to remove it."
          position: 'bottom'
          })
  opts.splice(28,0,{
          element: document.querySelector('#next-btn2')
          intro: "Click here to proceed and submit your query."
          position: 'right'
          })
  opts.splice(29,0,{
          element: document.querySelector('#search')
          intro: "Here you can see a summary of your query.  Click 'Submit' to submit your query and get your results.  Click 'Reset' to reset your query.  You can use the tabs to go back and modify your query."
          position: 'top'
          })

  intro.setOptions(
    {
      steps : opts
    }
  )


  # Manages scroll heights and active tabs depending on the step number
  intro.onbeforechange (targetElement) ->
    $.each opts, (index, step) ->
      if $(targetElement).is(step.element)
        switch index
          when 1
            $('#gene-search-tabs a[href="#gene-search-querygenes"]').tab 'show'
            window.scrollTo(0,0)
          when 2
            $('#gene-search-tabs a[href="#gene-search-querygenes"]').tab 'show'
            window.scrollTo(0,0)
          when 3
            $('#gene-search-tabs a[href="#gene-search-querygenes"]').tab 'show'
            window.scrollTo(0,0)
          when 4
            $('#gene-search-tabs a[href="#gene-search-querygenes"]').tab 'show'
            window.scrollTo(0,450)
          when 5
            $('#gene-search-tabs a[href="#gene-search-querygenes"]').tab 'show'
            window.scrollTo(0,450)
          when 6
            $('#gene-search-tabs a[href="#gene-search-querygenes"]').tab 'show'
            window.scrollTo(0,450)
          when 7
            $('#gene-search-tabs a[href="#gene-search-querygenes"]').tab 'show'
            window.scrollTo(0,450)
          when 8
            $('#gene-search-tabs a[href="#gene-search-querygenes"]').tab 'show'
            window.scrollTo(0,1400)
          when 9
            $('#gene-search-tabs a[href="#gene-search-querygenes"]').tab 'show'
            window.scrollTo(0,1400)
          when 10
            $('#gene-search-tabs a[href="#gene-search-querygenes"]').tab 'show'
            window.scrollTo(0,1400)
          when 11
            $('#gene-search-tabs a[href="#gene-search-querygenes"]').tab 'show'
            window.scrollTo(0,1400)
          when 12
            $('#gene-search-tabs a[href="#gene-search-querygenes"]').tab 'show'
            window.scrollTo(0,0)
          when 13
            $('#gene-search-tabs a[href="#gene-search-genomes"]').tab 'show'
            window.scrollTo(0,0)
          when 14
            $('#gene-search-tabs a[href="#gene-search-genomes"]').tab 'show'
            window.scrollTo(0,0)
          when 15
            $('#gene-search-tabs a[href="#gene-search-genomes"]').tab 'show'
            window.scrollTo(0,0)
          when 16
            $('#gene-search-tabs a[href="#gene-search-genomes"]').tab 'show'
            window.scrollTo(0,50)
          when 17
            $('#gene-search-tabs a[href="#gene-search-genomes"]').tab 'show'
            window.scrollTo(0,100)
          when 18
            $('#gene-search-tabs a[href="#gene-search-genomes"]').tab 'show'
            window.scrollTo(0,1150)
          when 19
            $('#gene-search-tabs a[href="#gene-search-genomes"]').tab 'show'
            window.scrollTo(0,1150)
          when 20
            $('#gene-search-tabs a[href="#gene-search-genomes"]').tab 'show'
            window.scrollTo(0,1200)
          when 21
            $('#gene-search-tabs a[href="#gene-search-genomes"]').tab 'show'
            window.scrollTo(0,1200)
          when 22
            $('#gene-search-tabs a[href="#gene-search-genomes"]').tab 'show'
            window.scrollTo(0,2000)
          when 23
            $('#gene-search-tabs a[href="#gene-search-genomes"]').tab 'show'
            window.scrollTo(0,2000)
          when 24
            $('#gene-search-tabs a[href="#gene-search-genomes"]').tab 'show'
            window.scrollTo(0,2000)
          when 25
            $('#gene-search-tabs a[href="#gene-search-genomes"]').tab 'show'
            window.scrollTo(0,2000)
          when 26
            $('#gene-search-tabs a[href="#gene-search-genomes"]').tab 'show'
            window.scrollTo(0,2000)
          when 27
            $('#gene-search-tabs a[href="#gene-search-genomes"]').tab 'show'
          when 28
            $('#gene-search-tabs a[href="#gene-search-submit"]').tab 'show'
            window.scrollTo(0,0)

  # For side panel to appear
  intro.onchange (targetElement) ->
   $.each opts, (index, step) ->
      if $(targetElement).is(step.element)
        switch index
          when 13
            document.getElementById('sidebar-wrapper').style.position = "absolute"
          when 14
            document.getElementById('sidebar-wrapper').style.position = "absolute"
          when 15
            document.getElementById('sidebar-wrapper').style.position = "absolute"
          when 16
            document.getElementById('sidebar-wrapper').style.position = "fixed"

  
  # Takes the user back to the "Select Genes" page
  intro.oncomplete  ->
    $('#gene-search-tabs a[href="#gene-search-querygenes"]').tab 'show'

  intro.start() 

  # Coffeescript will return the value of 
	# the last statement from function
  false

# END FUNC

# Make this function visible in global namespace
# If there isnt a function already called startIntro
unless root.startIntro
  root.startIntro = startIntro

