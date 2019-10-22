require(shiny)
require(statnet)
require(intergraph)
require(visNetwork)
require(colorspace)
require(network)
require(tidyverse)
require(readr)
require(igraph)

server <- function(input, output, session) {

  # set paths to Lego .png faces
    path_to_images <- "https://raw.githubusercontent.com/ScottStetkiewicz/AcademicNetworks/master/img/"

  # import dataframe of professors, departments and tags
    profs <- read_csv("profs.csv")

  # render shiny output
    output$network_proxy_nodes <- renderVisNetwork({

  # create nodes dataframe
    w2 <- profs %>%
      # split `Name` variable into first and last, extract lowercase last name for .png titles
      mutate(tempcol = stringr::str_split(Name, ' ')) %>%
      rowwise() %>%
      mutate(last_name = unlist(tolower(tempcol))[2]) %>%
      select(-tempcol) %>%
      # new variables for visNetwork images and labels
      mutate(image = paste0(path_to_images, last_name, ".png")) %>%
      mutate(label=Name) %>% 
    # separate instances of multiple tags delimited by commas
      separate_rows(Tags, sep = ", ", convert = TRUE) %>%
      group_by(Name, Tags, Department)

  # create affiliation matrix
    w4<-w2 %>% select(Name,Tags)
  # drop 'Department' grouping variable
    w4<-w4[,2:3]
  # convert to table
    aff <- table(w4)
  # create adjacency matrix
    m2=aff %*% t(aff)
  # create iGraph object
    g2=graph_from_adjacency_matrix(m2, "undirected", weighted=T, diag=F)
  # extract edgelist
    m3 = get.edgelist(g2)
  # function to create new vector of tag names for labelling edges
    lbls = sapply(1:NROW(m3), function(i){
      toString(names(which(aff[m3[i, 1],] == 1 & aff[m3[i, 2],] == 1)))
    })

  # multiple naming vectors
    faculty_names<-profs %>% select(Name,Department)
    faculty_names<-sort(faculty_names)
    Department<-faculty_names$Department

  # create Network object from adjacency matrix
    faculty.aff<-network(m2, matrix.type = 'adjacency', directed = FALSE)
    network::set.vertex.attribute(faculty.aff, 'Department', Department)
    network::set.edge.attribute(faculty.aff, 'Tags', lbls)

  # convert Network object to igraph
    faculty<-asIgraph(faculty.aff)

  # convert iGraph object to visNetwork
    data <- toVisNetworkData(faculty)
    # trim unecessary vectors
    data$nodes <- data$nodes%>% select(-label,-na)
    data$edges <- data$edges%>% select(-na)
    data$nodes <- data$nodes %>% rename(label = vertex.names)

  # set node images
    pic<-w2 %>% select(Name,image)
    pic<-sort(unique(pic[,3:4]))
    data$nodes$image<-pic$image
    
  # set colors for edges and nodes
    tag_col_var<-as.numeric(factor(data$edges$Tags))
    data$edges$color <- hcl.colors(length(unique(tag_col_var)))[tag_col_var]
    ledges <- data.frame(hcl.colors(length(unique(tag_col_var)))[tag_col_var])
    data$edges$title <- paste0("Shared Technology: ", lbls)
    dep_col_var<-as.numeric(factor(data$nodes$Department))
    data$nodes$color <- rainbow_hcl(length(unique(dep_col_var)))[dep_col_var]
   
  # set node titles
    data$nodes$title <- data$nodes$Department
    data$nodes<-data$nodes %>% mutate(shape = "circularImage")
    nodes<-as_tibble(data$nodes)
    nodes<-nodes %>% mutate(font.strokeWidth=5) 
    edges<-as_tibble(data$edges)
    
  # create visNetwork
    visNetwork(nodes, edges) %>%
        visNodes(size = input$size, 
                 shapeProperties = list(useBorderWithImage = TRUE),
                 borderWidth = 6) %>%
        visEdges(dashes = input$dashes, 
                 smooth = input$smooth, 
                 width = input$width) %>% 
      visOptions(selectedBy = "Department",
                 highlightNearest = list(enabled = input$highlightNearest, 
                                         hover = input$hover,
                                         algorithm = input$algorithm, 
                                         degree = input$deg,
                                         labelOnly = F)) %>% 
      visPhysics(forceAtlas2Based = list(
        avoidOverlap = .5,
        springLength = 150,
        gravitationalConstant = -10000
      )) %>% 
        visInteraction(selectConnectedEdges = F)
    
  })
}

ui <- fluidPage(

  fluidRow(
    column(
      width = 3,
      sliderInput("size", "Node Size : ", min = 1, max = 50, value = 20),
      sliderInput("width", "Edge Width : ", min = 1, max = 50, value = 3),
      hr(),
      checkboxInput("dashes", "Dashed Lines", FALSE),
      checkboxInput("smooth", "Edge Smoothing", TRUE),
      hr(),
      checkboxInput("highlightNearest", "Highlight Network Linkages?", T),
      checkboxInput("hover", "Highlight On Hover?", T),
      sliderInput("deg", "Linkage Degree :", min = 1, max = 10, value = 1),
      selectInput("algorithm", "Highlight Algorithm ", c("all", "hierarchical"))
    ),
    column(
      width = 9,
      visNetworkOutput("network_proxy_nodes", height = "800px", width = "100%")
    )
  )
 )

shinyApp(ui = ui, server = server)