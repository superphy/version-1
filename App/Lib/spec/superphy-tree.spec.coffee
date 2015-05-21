###


 File: superphy-tree.spec.coffee
 Desc: Jasmine test case for the TreeView class.
 Author: Matt Whiteside matthew.whiteside@phac-aspc.gc.ca
 Date: March 21th, 2013
 
 
###

# Initialise viewController and TreeView
viewController.init(public_genomes, private_genomes, 'multi_select', '/superphy/strains/info/')
viewController.createView('tree', jQuery('#strains_tree'), tree)
treeView = null
testGenome1 = 'public_3889'
testGenome2 = 'private_130'

describe "Creation of TreeView object by viewController createView method", ->
  
  it "should append instance of a TreeView object on the viewController views list", ->
    treeView = viewController.views[0]
    type = treeView.type
    expect(treeView? && type is 'tree').toBeTruthy()
    

describe "TreeView update method", ->
  
  it "should set tree node object properties to match corresponding genome properties in genomeController object - public test case (TC)", ->
    treeView.update(viewController.genomeController)
    node = treeView.nodes.filter( (d) => d.name is testGenome1 )[0];
    genome = viewController.genomeController.public_genomes[testGenome1]
   
    test = node.viewname? && node.viewname is genome.viewname
    test = test && node.selected? && node.selected is (genome.isSelected? and genome.isSelected)
    test = test && node.cssClass? && node.cssClass is genome.cssClass if genome.cssClass?
    
    expect(test).toBeTruthy()
    
  # it "should set tree node object properties to match corresponding genome properties in genomeController object - private TC", ->
    # treeView.update(viewController.genomeController)
    # node = treeView.nodes.filter( (d) => d.name is testGenome2 )[0];
    # genome = viewController.genomeController.public_genomes[testGenome1]
#    
    # test = node.viewname? && node.viewname is genome.viewname
    # test = test && node.selected? && node.selected is (genome.isSelected? and genome.isSelected)
    # test = test && node.cssClass? && node.cssClass is genome.cssClass if genome.cssClass?
#     
    # expect(test).toBeTruthy()
      
  # it "should set tree node object properties to match corresponding genome properties in genomeController object - private TC", ->
    # treeView.update(viewController.genomeController)
    # node = treeView.nodes.filter( (d) -> d.name is testGenome2 );
    # genome = viewController.genomeController.public_genomes[testGenome2]
#     
    # expect(node.viewname? && node.selected? && node.cssClass? && 
      # node.viewname is genome.viewname && node.selected is (genome.isSelected? and genome.isSelected) && node.cssClass is genome.cssClass).toBeTruthy()
#       
  # it "should remove tree node objects that have been filtered - public TC", ->
    # treeView.update(viewController.genomeController)
    # node = treeView.nodes.filter( (d) -> d.name is testGenome1 );
    # genome = viewController.genomeController.public_genomes[testGenome1]
#     
    # expect(node.viewname? && node.selected? && node.cssClass? && 
      # node.viewname is genome.viewname && node.selected is (genome.isSelected? and genome.isSelected) && node.cssClass is genome.cssClass).toBeTruthy()
    
  # it "should set selected"
#   
  # it "should select all sub"
#   
  # it "should update class"
#     
  # it 
    
   
  



