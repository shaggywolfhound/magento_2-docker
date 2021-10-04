<?php

$mapDir = false;
$location = false;

switch (true) {
    case stristr($_SERVER['HTTP_HOST'],'lay-z-spa'):
        $mapDir = 'lay-z-spa';
    break;
    case stristr($_SERVER['HTTP_HOST'],'bestwaystore'):
        $mapDir = 'bestwaystore';
    break;
}

if ($mapDir){
    $location = '/sitemaps/'.$mapDir.'/sitemap.xml';
}

if ($location && file_exists( __DIR__ . '/' . $location  )){
    //We'll be outputting a txt file
    header('Content-Type: text/xml');

    // It will be called downloaded.pdf
    //header('Content-Disposition: attachment; filename="sitemap.xml"');
    header('Content-Length: '.filesize( __DIR__ . '/' . $location));

    readfile( __DIR__ . '/' . $location);
    exit();
    //header('Location: /sitemaps/'.$mapDir.'/sitemap.xml', TRUE, 302);
}else{
        header("HTTP/1.0 404 Not Found");
}

exit();
